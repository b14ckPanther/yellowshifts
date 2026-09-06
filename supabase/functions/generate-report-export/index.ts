import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument, rgb } from "https://esm.sh/pdf-lib";
import fontkit from "https://esm.sh/@pdf-lib/fontkit";
import { heeboFontBase64 } from "./heebo_font_base64.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Cached font bytes from embedded base64
let cachedFontBytes: Uint8Array | null = null;
function getHeeboFontBytes(): Uint8Array {
  if (cachedFontBytes) return cachedFontBytes;
  const binaryString = atob(heeboFontBase64);
  cachedFontBytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    cachedFontBytes[i] = binaryString.charCodeAt(i);
  }
  return cachedFontBytes;
}

function getReportTypeLabel(type: string): string {
  switch (type.toUpperCase()) {
    case "STATION_ATTENDANCE_SUMMARY":
      return "סיכום נוכחות תחנה";
    case "MY_ATTENDANCE_HISTORY":
      return "היסטוריית נוכחות אישית";
    case "STATION_EMPLOYEE_WORKED_HOURS":
      return "שעות עבודה לפי עובד";
    case "DAILY_ATTENDANCE_REPORT":
      return "דוח נוכחות יומי";
    case "PUBLISHED_SCHEDULE":
      return "סידור עבודה מפורסם";
    case "AVAILABILITY_OVERVIEW":
      return "סקירת זמינות עובדים";
    case "AUDIT_LOGS":
      return "יומן ביקורת תפעולי";
    default:
      return type;
  }
}

function getColumnLabel(col: string): string {
  const map: Record<string, string> = {
    "Station": "תחנה",
    "Range Start": "מתאריך",
    "Range End": "עד תאריך",
    "Completed Shifts": "משמרות שהושלמו",
    "Worked Mins": "דקות עבודה",
    "Late Shifts": "איחורים",
    "Late Rate %": "% איחור",
    "Corrections": "תיקונים",
    "Employee": "עובד",
    "Role": "תפקיד",
    "Shift": "משמרת",
    "Check In": "כניסה",
    "Check Out": "יציאה",
    "Status": "סטטוס",
    "Total Worked Minutes": "סה״כ דקות",
  };
  return map[col] || col;
}

interface PdfTableData {
  stationName: string;
  stationCode: string;
  reportType: string;
  fromDate: string;
  toDate: string;
  requesterName: string;
  requesterEmail: string;
  generatedAt: string;
  columns: string[];
  rows: string[][];
}

async function buildA4Pdf(data: PdfTableData): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  pdfDoc.registerFontkit(fontkit);

  const fontBytes = await getHeeboFontBytes();
  const font = await pdfDoc.embedFont(fontBytes, { subset: true });
  const fontBold = await pdfDoc.embedFont(fontBytes, { subset: true });

  const pageWidth = 595.28;
  const pageHeight = 841.89;
  const margin = 40;
  const contentWidth = pageWidth - margin * 2; // 515.28 pt

  const colCount = Math.max(data.columns.length, 1);
  const colWidth = contentWidth / colCount;

  const firstPageRows = 20;
  const subsequentPageRows = 26;
  const totalRows = data.rows.length;

  const pagesData: string[][][] = [];
  let rowIndex = 0;

  if (totalRows === 0) {
    pagesData.push([]);
  } else {
    const page1Count = Math.min(totalRows, firstPageRows);
    pagesData.push(data.rows.slice(0, page1Count));
    rowIndex = page1Count;

    while (rowIndex < totalRows) {
      const count = Math.min(totalRows - rowIndex, subsequentPageRows);
      pagesData.push(data.rows.slice(rowIndex, rowIndex + count));
      rowIndex += count;
    }
  }

  const totalPages = pagesData.length;

  for (let p = 0; p < totalPages; p++) {
    const page = pdfDoc.addPage([pageWidth, pageHeight]);
    const pageNum = p + 1;
    const pageRows = pagesData[p];
    const isFirstPage = p === 0;

    // 1. Header Banner (First Page)
    if (isFirstPage) {
      // Dark Slate Bar
      page.drawRectangle({
        x: margin,
        y: pageHeight - margin - 60,
        width: contentWidth,
        height: 60,
        color: rgb(0.15, 0.17, 0.20),
      });

      // Gold Accent Line
      page.drawRectangle({
        x: margin,
        y: pageHeight - margin - 64,
        width: contentWidth,
        height: 4,
        color: rgb(0.96, 0.62, 0.04),
      });

      // Station Title & Code
      const titleText = `${data.stationName} [${data.stationCode}]`;
      page.drawText(titleText, {
        x: margin + 16,
        y: pageHeight - margin - 26,
        size: 15,
        font: fontBold,
        color: rgb(1, 1, 1),
      });

      // Report Header info
      const reportLabel = getReportTypeLabel(data.reportType);
      const subHeader = `דוח: ${reportLabel}  |  תקופה: ${data.fromDate} עד ${data.toDate}`;
      page.drawText(subHeader, {
        x: margin + 16,
        y: pageHeight - margin - 48,
        size: 9.5,
        font: font,
        color: rgb(0.95, 0.95, 0.95),
      });

      // Sub-header metadata
      const metaText = `הופק: ${data.generatedAt}  |  מבקש: ${data.requesterName} <${data.requesterEmail}>`;
      page.drawText(metaText, {
        x: margin,
        y: pageHeight - margin - 80,
        size: 8,
        font: font,
        color: rgb(0.4, 0.45, 0.5),
      });
    }

    // 2. Table Column Headers
    const tableTop = isFirstPage ? pageHeight - margin - 98 : pageHeight - margin - 20;
    const rowHeight = 22;

    // Header Background
    page.drawRectangle({
      x: margin,
      y: tableTop - rowHeight,
      width: contentWidth,
      height: rowHeight,
      color: rgb(0.23, 0.27, 0.33),
    });

    // Column Labels
    for (let c = 0; c < data.columns.length; c++) {
      const colName = getColumnLabel(data.columns[c]);
      const cellX = margin + c * colWidth + 6;
      const cellY = tableTop - rowHeight + 6;

      page.drawText(colName, {
        x: cellX,
        y: cellY,
        size: 8,
        font: fontBold,
        color: rgb(1, 1, 1),
      });
    }

    // 3. Table Rows
    let currentY = tableTop - rowHeight;

    for (let r = 0; r < pageRows.length; r++) {
      const rowData = pageRows[r];
      currentY -= rowHeight;

      // Row background
      page.drawRectangle({
        x: margin,
        y: currentY,
        width: contentWidth,
        height: rowHeight,
        color: r % 2 === 0 ? rgb(0.97, 0.98, 0.99) : rgb(1, 1, 1),
      });

      // Row bottom border
      page.drawLine({
        start: { x: margin, y: currentY },
        end: { x: margin + contentWidth, y: currentY },
        thickness: 0.5,
        color: rgb(0.90, 0.92, 0.94),
      });

      // Cells
      for (let c = 0; c < data.columns.length; c++) {
        let val = rowData[c] || "";
        if (val.length > 25) {
          val = val.substring(0, 23) + "...";
        }
        const cellX = margin + c * colWidth + 6;
        const cellY = currentY + 6;

        page.drawText(val, {
          x: cellX,
          y: cellY,
          size: 7.5,
          font: font,
          color: rgb(0.15, 0.17, 0.20),
        });
      }
    }

    // Outer Table Border
    const tableHeight = (pageRows.length + 1) * rowHeight;
    page.drawRectangle({
      x: margin,
      y: tableTop - tableHeight,
      width: contentWidth,
      height: tableHeight,
      borderColor: rgb(0.80, 0.83, 0.88),
      borderWidth: 1,
    });

    // 4. Running Footer
    const footerY = margin;
    page.drawLine({
      start: { x: margin, y: footerY + 12 },
      end: { x: margin + contentWidth, y: footerY + 12 },
      thickness: 0.5,
      color: rgb(0.85, 0.87, 0.90),
    });

    page.drawText(
      "YellowShifts Operational Report - Highly Confidential - Generated via Authoritative Engine",
      {
        x: margin,
        y: footerY,
        size: 7.5,
        font: font,
        color: rgb(0.5, 0.55, 0.6),
      }
    );

    const pageCountText = `עמוד ${pageNum} מתוך ${totalPages}`;
    page.drawText(pageCountText, {
      x: pageWidth - margin - 75,
      y: footerY,
      size: 7.5,
      font: fontBold,
      color: rgb(0.3, 0.35, 0.4),
    });
  }

  return await pdfDoc.save();
}

// ----------------------------------------------------------------------------
// HTTP Request Handler
// ----------------------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Missing Authorization header" } }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Verify caller session using JWT token
    const { data: { user: callerUser }, error: callerError } = await adminClient.auth.getUser(jwt);
    if (callerError || !callerUser) {
      return new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Invalid or expired session" } }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const body = await req.json().catch(() => ({}));
    const { export_id } = body;

    if (!export_id) {
      return new Response(
        JSON.stringify({ error: { code: "VALIDATION_ERROR", message: "Missing export_id" } }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Atomically claim export job (enforces PENDING -> PROCESSING transition)
    const { data: claimResult, error: claimError } = await callerClient.rpc("claim_report_export", {
      p_export_id: export_id,
    });

    if (claimError) {
      console.error("[generate-report-export] Claim error:", claimError);
      const isAuth = claimError.code === "42501" || claimError.message.includes("Access denied");
      const isExpired = claimError.code === "P0081" || claimError.message.includes("expired");
      const status = isAuth ? 403 : isExpired ? 410 : 400;

      return new Response(
        JSON.stringify({
          error: {
            code: isAuth ? "FORBIDDEN" : isExpired ? "EXPORT_EXPIRED" : "EXPORT_FAILED",
            message: claimError.message,
          },
        }),
        { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const exportType: string = claimResult.export_type || "REPORT";
    const exportFormat: string = (claimResult.format || "CSV").toUpperCase();

    // 3. Fetch structured dataset (re-verifies active caller role and permissions)
    const { data: dataset, error: datasetError } = await callerClient.rpc("get_report_export_dataset", {
      p_export_id: export_id,
    });

    if (datasetError) {
      console.error("[generate-report-export] Dataset error:", datasetError);
      const isAuth = datasetError.code === "42501" || datasetError.message.includes("Access denied");
      return new Response(
        JSON.stringify({
          error: {
            code: isAuth ? "FORBIDDEN" : "DATASET_ERROR",
            message: datasetError.message,
          },
        }),
        { status: isAuth ? 403 : 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let fileBytes: Uint8Array;
    let contentType: string;
    let fileExtension: string;
    let rowCount = dataset.row_count || 0;

    // 4. Generate artifact based on requested format
    if (exportFormat === "PDF") {
      fileBytes = await buildA4Pdf({
        stationName: dataset.station_name || "YellowShifts Station",
        stationCode: dataset.station_code || "YS",
        reportType: dataset.export_type || "Operational Report",
        fromDate: dataset.from_date || "",
        toDate: dataset.to_date || "",
        requesterName: dataset.requester_name || "",
        requesterEmail: dataset.requester_email || "",
        generatedAt: dataset.generated_at || new Date().toISOString(),
        columns: (dataset.columns || []) as string[],
        rows: (dataset.rows || []) as string[][],
      });
      contentType = "application/pdf";
      fileExtension = "pdf";
    } else {
      // Default: CSV with UTF-8 BOM & formula protection
      const { data: csvResult, error: csvError } = await callerClient.rpc("generate_report_export_csv", {
        p_export_id: export_id,
      });

      if (csvError) {
        throw csvError;
      }

      const csvContent: string = csvResult.csv_content || "";
      rowCount = csvResult.row_count || rowCount;
      fileBytes = new TextEncoder().encode(csvContent);
      contentType = "text/csv";
      fileExtension = "csv";
    }

    const fileSizeBytes = fileBytes.byteLength;

    // 5. Upload to private reports_storage bucket
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    const dateStamp = new Date().toISOString().split("T")[0];
    const storagePath = `exports/${exportType.toLowerCase()}/${dateStamp}_${export_id}.${fileExtension}`;
    const fileName = `${exportType.toLowerCase()}_${dateStamp}.${fileExtension}`;

    const { error: uploadError } = await adminClient.storage
      .from("reports_storage")
      .upload(storagePath, fileBytes, {
        contentType,
        upsert: true,
      });

    if (uploadError) {
      console.error("[generate-report-export] Storage upload error:", uploadError);
      return new Response(
        JSON.stringify({
          error: {
            code: "STORAGE_UPLOAD_ERROR",
            message: "Failed to persist export artifact",
          },
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Generate signed URL with strict 15-minute TTL (900 seconds) and download filename header
    const { data: signedUrlData, error: signedUrlError } = await adminClient.storage
      .from("reports_storage")
      .createSignedUrl(storagePath, 900, {
        download: fileName,
      });

    if (signedUrlError || !signedUrlData?.signedUrl) {
      console.error("[generate-report-export] Signed URL error:", signedUrlError);
      return new Response(
        JSON.stringify({
          error: {
            code: "SIGNED_URL_ERROR",
            message: "Failed to generate secure download link",
          },
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 7. Update export record metadata to COMPLETED
    await adminClient
      .from("report_exports")
      .update({
        storage_path: storagePath,
        file_size_bytes: fileSizeBytes,
        row_count: rowCount,
        completed_at: new Date().toISOString(),
        status: "COMPLETED",
      })
      .eq("id", export_id);

    return new Response(
      JSON.stringify({
        success: true,
        export_id,
        export_type: exportType,
        format: exportFormat,
        row_count: rowCount,
        file_size_bytes: fileSizeBytes,
        download_url: signedUrlData.signedUrl,
        expires_in_seconds: 900,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    console.error("[generate-report-export] Unexpected error:", err);
    const message = err instanceof Error ? err.message : "Internal server error";
    return new Response(
      JSON.stringify({
        error: {
          code: "INTERNAL_ERROR",
          message,
        },
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

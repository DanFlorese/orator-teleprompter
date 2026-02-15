import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { SmtpClient } from "https://deno.land/x/smtp@v0.7.0/mod.ts"
import { writeAll } from "https://deno.land/std@0.168.0/streams/write_all.ts"

if (typeof (Deno as any).writeAll !== "function") {
  (Deno as any).writeAll = writeAll;
}

serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}));
    const record = body?.record || body || {};
    const userEmail = record?.email || "mafahlacapital@gmail.com";
    const userName = record?.full_name || "Speaker";

    const publicLogoUrl = "https://nbkmpybfpurecjculpib.supabase.co/storage/v1/object/public/assets/orator_teleprompter.png";

    const client = new SmtpClient();
    
    await client.connect({
      hostname: "smtp.hostinger.com",
      port: 587,
      username: Deno.env.get("SMTP_USERNAME"),
      password: Deno.env.get("SMTP_PASSWORD"),
    });

    // Eliminamos espacios en blanco innecesarios al inicio/final del HTML
    const emailHtml = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body style="margin:0; padding:0; background-color:#000000; color:#ffffff; font-family:Arial,sans-serif;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color:#000000;">
    <tr>
      <td align="center" style="padding:40px 10px;">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width:500px; background-color:#111111; border:2px solid #ff0000; border-radius:20px; overflow:hidden;">
          <tr>
            <td align="center" style="padding:30px 0;">
              <img src="${publicLogoUrl}" alt="Orator" width="150" style="display:block; border-radius:8px;">
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:0 30px;">
              <h1 style="color:#ff0000; font-size:24px; text-transform:uppercase; margin:0;">Ready for the stage?</h1>
              <p style="font-size:16px; line-height:1.5; margin:20px 0;">Hi <strong>${userName}</strong>, welcome to Orator. Your professional setup is active.</p>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:20px 0 40px 0;">
              <a href="https://tu-app-url.com" style="background-color:#ff0000; color:#ffffff; padding:15px 30px; text-decoration:none; font-weight:bold; border-radius:50px; display:inline-block;">START RECORDING NOW</a>
            </td>
          </tr>
          <tr>
            <td align="center" style="background-color:#1a1a1a; padding:15px; color:#666666; font-size:12px;">
              REC • AUDIO • CHAT • VIDEO
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`.trim();

    await client.send({
      from: "support@oratorteleprompter.com",
      to: userEmail,
      subject: "Welcome to Orator Teleprompter! 🎙️",
      content: "text/html",
      body: emailHtml,
    });

    await client.close();
    return new Response(JSON.stringify({ status: "success" }), { 
      status: 200,
      headers: { "Content-Type": "application/json" }
    });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { 
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
})
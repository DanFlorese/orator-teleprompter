import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { SmtpClient } from "https://deno.land/x/smtp@v0.7.0/mod.ts"
import { writeAll } from "https://deno.land/std@0.168.0/streams/write_all.ts"

// PARCHE DE COMPATIBILIDAD
if (typeof Deno.writeAll !== "function") {
  (Deno as any).writeAll = writeAll;
}

serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}));
    const record = body?.record || body || {};
    const userEmail = record?.email || "mafahlacapital@gmail.com";
    const userName = record?.full_name || "User";

    const client = new SmtpClient();
    await client.connect({
      hostname: "smtp.hostinger.com",
      port: 587,
      username: Deno.env.get("SMTP_USERNAME"),
      password: Deno.env.get("SMTP_PASSWORD"),
    });

    await client.send({
      from: "support@oratorteleprompter.com",
      to: userEmail,
      subject: "Welcome to Orator Teleprompter! 🎙️",
      content: "text/html", // Activamos HTML
      body: `
        <div style="background-color: #000; color: #fff; font-family: 'Helvetica', sans-serif; padding: 40px; text-align: center; border: 2px solid #ff0000; border-radius: 15px;">
          <h1 style="color: #ff0000; font-size: 30px; text-transform: uppercase;">Orator Teleprompter</h1>
          <hr style="border: 0; border-top: 1px solid #333; margin: 20px auto; width: 50%;">
          <h2 style="font-size: 22px;">Hi, ${userName}!</h2>
          <p style="font-size: 16px; line-height: 1.6; color: #ccc;">
            Your stage is ready. Start delivering powerful messages with the precision of a pro.
          </p>
          <div style="margin: 35px 0;">
            <a href="https://tu-app-url.com" style="background-color: #ff0000; color: #fff; padding: 15px 35px; text-decoration: none; font-weight: bold; border-radius: 5px; font-size: 16px;">
              OPEN YOUR TELEPROMPTER
            </a>
          </div>
          <p style="color: #666; font-size: 12px; margin-top: 50px;">
            &copy; 2026 Orator Teleprompter. Designed for the bold.
          </p>
        </div>
      `,
    });

    await client.close();
    return new Response(JSON.stringify({ status: "success" }), { status: 200 });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
})
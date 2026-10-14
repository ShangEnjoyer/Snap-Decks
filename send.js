// Vercel serverless function: receives the deck text and posts it to Discord.
// The webhook URL lives in the DISCORD_WEBHOOK_URL environment variable, never in the site code.
export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ ok: false });

  // Only accept requests coming from this same site
  const origin = req.headers.origin;
  if (origin && new URL(origin).host !== req.headers.host) return res.status(403).json({ ok: false });

  let body = req.body;
  try { if (typeof body === "string") body = JSON.parse(body); } catch (e) { return res.status(400).json({ ok: false }); }

  const content = body && body.content;
  if (typeof content !== "string" || !content.trim() || content.length > 1900) return res.status(400).json({ ok: false });
  if (!content.startsWith("```")) return res.status(400).json({ ok: false });   // the site always sends a code block

  const r = await fetch(process.env.DISCORD_WEBHOOK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content, username: "Deck Decoder", allowed_mentions: { parse: [] } })
  });
  return res.status(r.ok ? 200 : 502).json({ ok: r.ok });
}

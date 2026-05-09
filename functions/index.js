const functions = require("firebase-functions");
const fetch = require("node-fetch");

// Gemini API Key — loaded from environment variable for security.
// Set it with: firebase functions:secrets:set GEMINI_API_KEY
// Or set via .env file for local development.
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

exports.generateAIResponse = functions.https.onRequest(async (req, res) => {
  // Fail fast if API key is not configured
  if (!GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY is not set. Configure it via environment variables.");
    return res.status(500).json({ error: "Server misconfiguration: API key not set" });
  }

  // Set CORS headers for Flutter Web support if needed
  res.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    // Send response to OPTIONS requests
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const userInput = req.body.input;

  if (!userInput) {
    return res.status(400).json({ error: "No input provided" });
  }

  try {
    console.log("Generating AI response for input length:", userInput.length);

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [{ text: userInput }],
            },
          ],
        }),
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      console.error("Gemini API Error:", errorData);
      return res.status(response.status).json({ error: "Gemini API failure", details: errorData });
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error("Internal Error:", error);
    res.status(500).json({ error: "AI generation failed", message: error.message });
  }
});

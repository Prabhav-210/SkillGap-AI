const express = require("express");
const fetch = require("node-fetch");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

// Gemini API Key — loaded from environment variable for security.
// Create a .env file with: GEMINI_API_KEY=your_key_here
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

if (!GEMINI_API_KEY) {
  console.warn("WARNING: GEMINI_API_KEY is not set. API calls will fail.");
}

// Health check endpoint
app.get("/", (req, res) => {
  res.json({ status: "ok", hasApiKey: !!GEMINI_API_KEY });
});

app.post("/generate", async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(500).json({ error: "Server misconfiguration: API key not set" });
  }

  const userInput = req.body.input;

  if (!userInput) {
    return res.status(400).json({ error: "No input provided" });
  }

  try {
    console.log("Generating AI response for input length:", userInput.length);

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
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
      return res.status(response.status).json({ error: "Gemini API failure" });
    }

    const data = await response.json();

    // Extract text from Gemini response structure
    const text =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ||
      "No response from AI";

    res.json({ result: text });
  } catch (error) {
    console.error("Server Error:", error);
    res.status(500).json({ error: "AI generation failed" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

local Env = getgenv()

Env.api_key = "gsk_123" -- Groq Api Key
Env.tts_endpoint = "https://your-app.up.railway.app/" -- https://github.com/adm400ba/edgetts
Env.yt_dlp_endpoint = "https://your-app.up.railway.app" -- https://github.com/adm400ba/yt-dlp-endpoint

loadstring(game:HttpGet("https://github.com/adm400ba/Jarvis/raw/refs/heads/main/src/Jarvis.lua"))()

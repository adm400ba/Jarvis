getgenv().api_key = "gsk_123" -- Groq Api Key
getgenv().tts_endpoint = "https://your-app.up.railway.app/gerar-audio" -- https://github.com/adm400ba/edgetts
getgenv().yt_dlp_endpoint = "https://your-app.up.railway.app" -- https://github.com/adm400ba/yt-dlp-endpoint

loadstring(game:HttpGet("https://github.com/adm400ba/Jarvis/raw/refs/heads/main/src/Jarvis.lua"))()

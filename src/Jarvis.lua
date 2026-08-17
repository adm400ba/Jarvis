--[[
     ____.  _____ ______________   ____.___  _________
    |    | /  _  \______   \   \ /   /|   |/   _____/
    |    |/  /_\  \|       _/\   Y   / |   |\_____  \ 
/\__|    /    |    \    |   \ \     /  |   |/        \
\________\____|__  /____|_  /  \___/   |___/_______  /
                 \/       \/                       \/ 

Just A Rather Very Intelligent System.

- Jarvis, play Megalovania by Toby Fox.
- Jarvis, set my WalkSpeed to 50.       
- Jarvis, How many stars are there in the universe?
]]

local VERSION = "v0.1.1"          

local Players = cloneref(game:GetService("Players"))
local TextChatService = cloneref(game:GetService("TextChatService"))
local HttpService = cloneref(game:GetService("HttpService"))
local RunService = cloneref(game:GetService("RunService"))
local Lighting = cloneref(game:GetService("Lighting"))
local StarterGui = cloneref(game:GetService("StarterGui"))

SendNotification = function(Text, Description, Duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(Text or "Notification"),
            Text = tostring(Description or ""),
            Duration = tonumber(Duration) or 5
        })
    end)
end

if getgenv().JarvisLoaded then
warn("Jarvis already loaded!\n" .. VERSION)
SendNotification("Jarvis already loaded", "Jarvis already loaded!\n" .. VERSION, 5)
return
end

if not getgenv().api_key then
warn("api_key is missing.")
SendNotification("Missing variable", "api_key is missing.", 5)
elseif not getgenv().tts_endpoint then
warn("tts_endpoint is missing.")
SendNotification("Missing variable", "tts_endpoint is missing.", 5)
elseif not getgenv().yt_dlp_endpoint then
warn("yt_dlp_endpoint is missing.")
SendNotification("Missing variable", "yt_dlp_endpoint is missing.", 5)
end

if not isfolder("Jarvis") then makefolder("Jarvis") end
if not isfolder("Jarvis/jarvis_voice") then makefolder("Jarvis/jarvis_voice") end
if not isfolder("Jarvis/jarvis_yt_musics") then makefolder("Jarvis/jarvis_yt_musics") end
local TOKEN = getgenv().api_key
local MODEL = "openai/gpt-oss-120b"
local TTS_URL = getgenv().tts_endpoint
local FollowConnection = nil
local NoclipConnection = nil
local AntiSitConnection = nil
local NoclipParts = {}
local ConversationHistory = {}

local TTSSound = workspace:FindFirstChild("JarvisTTSPlayer") or Instance.new("Sound")
TTSSound.Name = "JarvisTTSPlayer"
TTSSound.Volume = 1
TTSSound.Parent = workspace

local MusicSound = workspace:FindFirstChild("JarvisMusicPlayer") or Instance.new("Sound")
MusicSound.Name = "JarvisMusicPlayer"
MusicSound.Volume = 1
MusicSound.Looped = true
MusicSound.Parent = workspace
getgenv().CurrentMusicSound = MusicSound

getgenv().CurrentMusicTitle = nil
getgenv().CurrentMusicChannel = nil
getgenv().CurrentMusicDescription = nil
getgenv().CurrentMusicViews = nil

local SYSTEM_PROMPT = [[
You are Jarvis, an intelligent AI assistant integrated into Roblox.

Rules:
- Keep normal replies under 120 characters.
- Never exceed this limit.
- If a user request matches a command, return ONLY a JSON object.
- Never include explanations before or after JSON.
- Never use markdown.
- Never wrap JSON in code blocks.
- When returning a command, always include a "reply" field.
- The "reply" field must be a short, natural confirmation related to the action.
- Vary confirmation messages and avoid repeating the same wording.
- Understand spelling mistakes, abbreviations, slang, and alternative wording.

Available commands:
{"command":"jump"}
{"command":"sit"}
{"command":"reset"}
{"command":"speed","value":number}
{"command":"jumppower","value":number}
{"command":"teleport","player":"name"}
{"command":"follow","player":"name"}
{"command":"unfollow"}
{"command":"say","message":"text"}
{"command":"time","value":number}
{"command":"gravity","value":number}
{"command":"noclip"}
{"command":"unnoclip"}
{"command":"antisit"}
{"command":"unantisit"}
{"command":"iy"}
{"command":"fly"}
{"command":"tpto","x":number,"y":number,"z":number}
{"command":"antivoid"}
{"command":"unantivoid"}
{"command":"playmusic","query":"name or url"}
{"command":"stopmusic"}
{"command":"pausemusic"}
{"command":"resumemusic"}
{"command":"musicvolume","value":number}

Command recognition examples:
Jump:
- jump
- jump up

Sit:
- sit
- sit down

Reset:
- reset
- die

Speed:
- speed 50

Jump Power:
- jumppower 100

Teleport to player:
- teleport to player

Follow:
- follow name

Unfollow:
- unfollow

Say:
- say hello

Time:
- time 12

Gravity:
- gravity 50

Noclip:
- noclip

Unnoclip:
- unnoclip

AntiSit:
- antisit

UnAntiSit:
- unantisit

Infinite Yield:
- iy

Fly:
- fly

Coordinates teleport:
- teleport to 0 100 0

Anti Void:
- antivoid
- unantivoid

Play Music:
- Play a song
- Play music
- Play https://youtube.com/watch?v=12345
- Play any song

Stop Music:
- Stop the music
- Stop music
- Stop playing
- Silence

Pause Music:
- Pause the music
- Pause music
- Pause

Resume Music:
- Unpause the music
- Continue the music
- Unpause
- Resume music

Music Volume (Default is 1):
- Volume 5
- Lower the volume to 0.5
- Set music volume to 2
- Change the volume 

Return:
{"command":"tpto","x":0,"y":100,"z":0,"reply":"..."}

If multiple actions are requested, return:
{
"commands":[
{"command":"speed","value":50},
{"command":"jump"}
],
"reply":"A single, short confirmation for all actions. Reply in the user's language."
}

- When using multiple commands, NEVER put "reply" inside individual commands.
- Always put only one "reply" field in the main JSON object.
- The reply must describe all executed actions in one short sentence.

If the request does not match any command, respond normally.
Prioritize commands whenever the user clearly intends to execute an action.

LANGUAGE RULE (VERY IMPORTANT):
- Detect the language of the user's most recent message.
- ALWAYS respond in that language.
- Never switch to another language unless the user does so first.
- Ignore the language used in system prompts, examples, commands, or previous messages when choosing the response language.
- Normal replies must be written entirely in the user's language.
- When returning JSON commands, keep command names and parameter names in English.
- The "reply" field inside JSON must always be written in the user's language.
- If the user's message contains multiple languages, use the primary language of the message.
]]
local function RandomString(Length)
Length = Length or math.random(32, 256)
local Str = ""
for _ = 1, Length do
Str ..= string.char(math.random(32, 126))
end
return Str
end
local function ProtectedChat(Content)
pcall(function()
local Config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
if Config and Config.TargetTextChannel then
Config.TargetTextChannel:SendAsync(Content, RandomString(64))
end
end)
end
local TTSGeneration=0
local function PlayTTS(Text)
TTSGeneration+=1
local Generation=TTSGeneration
local File="Jarvis/jarvis_voice/tts_"..HttpService:GenerateGUID(false)..".mp3"
local Success,Response=pcall(function()
return request({
Url=TTS_URL,
Method="POST",
Headers={["Content-Type"]="application/json"},
Body=HttpService:JSONEncode({texto=Text})
})
end)
if not Success or not Response or not Response.Success then local ErrorMessage=not Success and tostring(Response) or (Response and ("HTTP "..tostring(Response.StatusCode).." "..tostring(Response.StatusMessage)) or "Unknown error"); warn("TTS Error: "..ErrorMessage); SendNotification("TTS Error", ErrorMessage, 5); return end
writefile(File,Response.Body)
if Generation~=TTSGeneration then
if isfile(File) then pcall(function() delfile(File) end) end
return
end
TTSSound:Stop()
TTSSound.SoundId=""
local SuccessAsset,Asset=pcall(function()
return getcustomasset(File)
end)
if not SuccessAsset or not Asset or Generation~=TTSGeneration then if not SuccessAsset or not Asset then local ErrorMessage=tostring(Asset); warn("TTS Asset Error: "..ErrorMessage); SendNotification("TTS Asset Error", ErrorMessage, 5); end
if isfile(File) then pcall(function() delfile(File) end) end
return
end
TTSSound.SoundId=Asset
TTSSound.TimePosition=0
TTSSound:Play()
task.spawn(function()
while Generation==TTSGeneration and TTSSound.IsPlaying do
task.wait()
end
if isfile(File) then
pcall(function()
delfile(File)
end)
end
end)
end
local function GetPlayer(Name)
local Query = tostring(Name):lower():gsub("[%W_]", "")
if Query == "" then return nil end
for _, P in ipairs(Players:GetPlayers()) do
local PName = P.Name:lower():gsub("[%W_]", "")
local DName = P.DisplayName:lower():gsub("[%W_]", "")
if PName:find(Query) or DName:find(Query) then
return P
end
end
return nil
end
local function EnableNoclip()
if NoclipConnection then NoclipConnection:Disconnect() end
NoclipParts = {}
NoclipConnection = RunService.Stepped:Connect(function()
local Character = Players.LocalPlayer.Character
if not Character then return end
for _, Part in ipairs(Character:GetDescendants()) do
if Part:IsA("BasePart") and Part.CanCollide then
Part.CanCollide = false
NoclipParts[Part] = true
end
end
end)
end
local function DisableNoclip()
if NoclipConnection then
NoclipConnection:Disconnect()
NoclipConnection = nil
end
for Part in pairs(NoclipParts) do
if Part and Part.Parent then Part.CanCollide = true end
end
table.clear(NoclipParts)
end
local function ExtractVideoID(Url)
local Id = Url:match("v=([%w-_]+)")
if not Id then Id = Url:match("youtu%.be/([%w-_]+)") end
if not Id then Id = Url:match("embed/([%w-_]+)") end
return Id
end
local function FetchYtInfo(Url)
local Success, Result = pcall(function()
local Req = request({ Url = Url, Method = "GET" })
if Req.Success then return HttpService:JSONDecode(Req.Body) end
end)
if Success and Result and Result.results and #Result.results > 0 then
return Result
end
return nil
end
local CommandHandlers = {
jump = function(Data, Lp, Char, Hum) if Hum then Hum.Jump = true end end,
sit = function(Data, Lp, Char, Hum) if Hum then Hum.Sit = true end end,
reset = function(Data, Lp, Char, Hum) if Hum then Hum.Health = 0 end end,
speed = function(Data, Lp, Char, Hum) if Hum then Hum.WalkSpeed = tonumber(Data.value) or 16 end end,
jumppower = function(Data, Lp, Char, Hum)
if Hum then Hum.UseJumpPower = true; Hum.JumpPower = tonumber(Data.value) or 50 end
end,
teleport = function(Data, Lp, Char, Hum, Hrp)
if Hrp then
local Target = GetPlayer(Data.player)
if Target and Target.Character and Target.Character:FindFirstChild("HumanoidRootPart") then
Hrp.CFrame = Target.Character.HumanoidRootPart.CFrame
end
end
end,
follow = function(Data, Lp)
local Target = GetPlayer(Data.player)
if FollowConnection then FollowConnection:Disconnect() FollowConnection = nil end
if Target then
FollowConnection = RunService.Heartbeat:Connect(function()
local TChar = Target.Character
local THrp = TChar and TChar:FindFirstChild("HumanoidRootPart")
if THrp and Lp.Character and Lp.Character:FindFirstChildOfClass("Humanoid") then
Lp.Character:FindFirstChildOfClass("Humanoid"):MoveTo(THrp.Position)
else
if FollowConnection then FollowConnection:Disconnect() FollowConnection = nil end
end
end)
end
end,
unfollow = function()
if FollowConnection then FollowConnection:Disconnect() FollowConnection = nil end
end,
say = function(Data)
if Data.message then ProtectedChat(tostring(Data.message)) end
end,
time = function(Data)
local Val = tonumber(Data.value)
if Val then Lighting.ClockTime = Val end
end,
gravity = function(Data)
local Val = tonumber(Data.value)
if Val then workspace.Gravity = Val end
end,
noclip = EnableNoclip,
unnoclip = DisableNoclip,
antisit = function(Data, Lp)
if AntiSitConnection then AntiSitConnection:Disconnect() end
AntiSitConnection = RunService.Heartbeat:Connect(function()
local CurrentHum = Lp.Character and Lp.Character:FindFirstChildOfClass("Humanoid")
if CurrentHum then CurrentHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end
end)
end,
unantisit = function(Data, Lp, Char, Hum)
if AntiSitConnection then AntiSitConnection:Disconnect() AntiSitConnection = nil end
if Hum then Hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end
end,
iy = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end,
fly = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/XNEOFF/FlyGuiV3/main/FlyGuiV3.txt"))() end,
tpto = function(Data, Lp, Char, Hum, Hrp)
if Hrp then
local X, Y, Z = tonumber(Data.x), tonumber(Data.y), tonumber(Data.z)
if X and Y and Z then Hrp.CFrame = CFrame.new(X, Y, Z) end
end
end,
antivoid = function() workspace.FallenPartsDestroyHeight = 0/0 end,
unantivoid = function() workspace.FallenPartsDestroyHeight = -500 end,
stopmusic = function()
if getgenv().CurrentMusicSound then
getgenv().CurrentMusicSound:Stop()
end
getgenv().CurrentMusicTitle = nil
getgenv().CurrentMusicChannel = nil
getgenv().CurrentMusicViews = nil
end,
pausemusic = function() if getgenv().CurrentMusicSound then getgenv().CurrentMusicSound:Pause() end end,
resumemusic = function() if getgenv().CurrentMusicSound then getgenv().CurrentMusicSound:Resume() end end,
musicvolume = function(Data)
if getgenv().CurrentMusicSound then getgenv().CurrentMusicSound.Volume = tonumber(Data.value) or 1 end
end,
playmusic = function(Data)
if not Data.query then return end
task.spawn(function()
local Query = tostring(Data.query)
local VideoId = ExtractVideoID(Query)
local VideoUrl = Query
local Title, Channel = "Unknown", "Unknown"
local Views = 0
if not VideoId then
local Info = FetchYtInfo(getgenv().yt_dlp_endpoint .. "/search?q=" .. HttpService:UrlEncode(Query))
if Info and Info.results then
local BestResult, BestScore
local QueryLower = Query:lower():gsub("[%p]", " ")
local QueryWords = {}
for Word in QueryLower:gmatch("[%wÀ-ÿ]+") do
if #Word > 1 then
table.insert(QueryWords, Word)
end
end
for _, Result in ipairs(Info.results) do
local Score = 0
local TitleLower = tostring(Result.title or ""):lower()
local ChannelLower = tostring(Result.channel or ""):lower()
local DescriptionLower = tostring(Result.description or ""):lower()
local MatchedWords = 0
for _, Word in ipairs(QueryWords) do
if TitleLower:find(Word, 1, true) then
Score += 100
MatchedWords += 1
elseif ChannelLower:find(Word, 1, true) then
Score += 20
elseif DescriptionLower:find(Word, 1, true) then
Score += 5
end
end
if #QueryWords > 0 and MatchedWords == #QueryWords then
Score += 1000
end
if TitleLower == QueryLower then
Score += 5000
end
local ViewsValue = tonumber(Result.views) or 0
if ViewsValue > 0 then
Score += math.min(math.log10(ViewsValue) * 10, 100)
end
if not BestScore or Score > BestScore then
BestScore = Score
BestResult = Result
end
end
if BestResult then
VideoId, VideoUrl, Title, Channel = BestResult.id, BestResult.url, BestResult.title, BestResult.channel
Views = tonumber(BestResult.views) or 0
getgenv().CurrentMusicDescription = BestResult.description or "Unknown"
getgenv().CurrentMusicViews = Views
end
end
else
local Info = FetchYtInfo(getgenv().yt_dlp_endpoint .. "/search?q=" .. HttpService:UrlEncode(VideoUrl))
if Info and Info.results and Info.results[1] then
local Result = Info.results[1]
Title, Channel = Result.title, Result.channel
Views = tonumber(Result.views) or 0
getgenv().CurrentMusicDescription = Result.description or "Unknown"
getgenv().CurrentMusicViews = Views
end
end
if not VideoId then return end
getgenv().CurrentMusicTitle = Title
getgenv().CurrentMusicChannel = Channel
local FilePath = "Jarvis/jarvis_yt_musics/" .. VideoId .. ".mp3"
if not isfile(FilePath) then
warn("Processing audio...")
SendNotification("Processing audio...", "Please wait, processing audio.", 5)
local Success,Error=pcall(function()
local Req=request({
Url=getgenv().yt_dlp_endpoint.."/mp3?url="..HttpService:UrlEncode(VideoUrl),
Method="GET"
})
if Req.Success then
writefile(FilePath,Req.Body)
else
warn("Failed to process audio!")
warn("Status Code: "..tostring(Req.StatusCode))
warn("Status Message: "..tostring(Req.StatusMessage))
warn("Server Response: "..tostring(Req.Body))
SendNotification("Failed to process audio","Server returned HTTP "..tostring(Req.StatusCode),5)
end
end)
if not Success then
warn("Request Error: "..tostring(Error))
end
end
if isfile(FilePath) then
if getgenv().CurrentMusicSound then
getgenv().CurrentMusicSound:Stop()
getgenv().CurrentMusicSound.SoundId = getcustomasset(FilePath)
getgenv().CurrentMusicSound.TimePosition = 0
getgenv().CurrentMusicSound:Play()
end
end
end)
end
}
local function ExecuteCommand(Data)
if type(Data) ~= "table" or not Data.command then return end
local Lp = Players.LocalPlayer
local Char = Lp.Character
local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
local Hrp = Char and Char:FindFirstChild("HumanoidRootPart")
local Handler = CommandHandlers[Data.command]
if Handler then
Handler(Data, Lp, Char, Hum, Hrp)
end
end
local function ParseJSON(Text)
local Cleaned = Text:match("^```[jJ][sS][oO][nN]%s*(.-)%s*```$") or Text:match("^```%s*(.-)%s*```$") or Text
local Success, Result = pcall(function()
return HttpService:JSONDecode(Cleaned)
end)
if Success and type(Result) == "table" then
return Result
end
return nil
end
local function AskJarvis(Prompt)
table.insert(ConversationHistory, { role = "user", content = Prompt })
if #ConversationHistory > 20 then
table.remove(ConversationHistory, 1)
end
local CurrentSysPrompt = SYSTEM_PROMPT
if getgenv().CurrentMusicTitle and getgenv().CurrentMusicChannel then
CurrentSysPrompt = CurrentSysPrompt .. "\nCurrently playing music: " .. getgenv().CurrentMusicTitle .. " by channel: " .. getgenv().CurrentMusicChannel .. ". Description: " .. tostring(getgenv().CurrentMusicDescription) .. ". Views: " .. tostring(getgenv().CurrentMusicViews or 0) .. ". The default volume is 1."
end
local Messages = { { role = "system", content = CurrentSysPrompt } }
for _, Msg in ipairs(ConversationHistory) do
table.insert(Messages, Msg)
end
local Body = HttpService:JSONEncode({
model = MODEL,
messages = Messages,
temperature = 0.7
})
local Response
local LastError = "Unknown error"
for _ = 1, 3 do
local Success, Result = pcall(function()
return request({
Url = "https://api.groq.com/openai/v1/chat/completions",
Method = "POST",
Headers = {
Authorization = "Bearer " .. TOKEN,
["Content-Type"] = "application/json"
},
Body = Body
})
end)
if Success and Result and Result.StatusCode == 200 then
Response = Result
break
end
if not Success then
LastError = tostring(Result)
elseif Result then
LastError = "HTTP " .. tostring(Result.StatusCode) .. " " .. tostring(Result.StatusMessage)
else
LastError = "No response received"
end
task.wait(2)
end
if not Response then warn("Response Error: "..LastError); SendNotification("Response Error", LastError, 5); return "Failed to connect to API." end
local Ok, Data = pcall(function() return HttpService:JSONDecode(Response.Body) end)
if not Ok then warn("Response Error: "..tostring(Data)); SendNotification("Response Error", tostring(Data), 5); return "Failed to parse API response." end
local Text
pcall(function() Text = Data.choices[1].message.content end)
if not Text or Text == "" then warn("Response Error: Empty response from API"); SendNotification("Response Error", "Empty response from API", 5); return "No response." end
table.insert(ConversationHistory, { role = "assistant", content = Text })
if #ConversationHistory > 20 then
table.remove(ConversationHistory, 1)
end
return Text
end
TextChatService.MessageReceived:Connect(function(Message)
local Source = Message.TextSource
if not Source then return end
if Source.UserId ~= Players.LocalPlayer.UserId then return end
local Text = Message.Text
if Text:sub(1, 6):lower() ~= "jarvis" then return end
local Prompt = Text:sub(7):gsub("^%s+", "")
if Prompt == "" then return end
task.spawn(function()
local Reply = AskJarvis(Prompt)
if not Reply then return end
local JsonData = ParseJSON(Reply)
if JsonData then
if JsonData.commands and type(JsonData.commands) == "table" then
for _, Cmd in ipairs(JsonData.commands) do
ExecuteCommand(Cmd)
task.wait(0.1)
end
if JsonData.reply and type(JsonData.reply) == "string" then
ProtectedChat(JsonData.reply)
PlayTTS(JsonData.reply)
end
elseif JsonData.command then
if JsonData.reply and type(JsonData.reply) == "string" then
ProtectedChat(JsonData.reply)
PlayTTS(JsonData.reply)
end
task.spawn(function()
ExecuteCommand(JsonData)
end)
end
else
Reply = Reply:gsub("[\r\n]+", " ")
Reply = Reply:gsub("^%s+", "")
Reply = Reply:gsub("%s+$", "")
local MaxLength = 200
if #Reply > MaxLength then
Reply = Reply:sub(1, MaxLength) .. "..."
end
ProtectedChat(Reply)
PlayTTS(Reply)
end
end)
end)
warn("Jarvis loaded!\n" .. VERSION)
SendNotification("Jarvis loaded", "Jarvis successfully loaded!\n" .. VERSION, 5)
getgenv().JarvisLoaded = true
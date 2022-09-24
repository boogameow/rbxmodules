local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer
local Replicated = game:GetService("ReplicatedStorage")

local Maid = require(Replicated.Maid)

local Preload = {}
Preload.__index = Preload
Preload.ClassName = "Preload"

-- Constructor

function Preload.new()
	local self = setmetatable({}, Preload)
	
	self.Items = 0
	self.Finished = 0
	
	self.Maid = Maid.new()
	
	return self
end

function Preload:Build()
	self.Screen = Instance.new("ScreenGui")
	self.Screen.IgnoreGuiInset = true
	self.Screen.ResetOnSpawn = false
	self.Screen.Name = "PreloadGui"
	self.Screen.Parent = Player.PlayerGui

	self.Container = Instance.new("Frame")
	self.Container.Transparency = 1
	self.Container.AnchorPoint = Vector2.new(1, 0)
	self.Container.Position = UDim2.new(1, 0, 0, 0)
	self.Container.Size = UDim2.new(0.001, 0, 0.001, 0)
	self.Container.Name = "Container"
	self.Container.Parent = self.Screen
	
	self.Maid:GiveTask(self.Screen)
	self.Maid:GiveTask(self.Container)
	
	self.Maid:GiveTask(function()
		self.Built = nil
		self.Items = 0
		self.Finished = 0
	end)
	
	self.Built = true
end

-- Main

function Preload:_Add(ID, Type)
	if self.Maid[ID] then
		return
	end
	
	if not self.Built then
		self:Build()
	end
	
	self.Items += 1
	
	local Object
	
	if Type == "Image" then
		Object = Instance.new("ImageLabel")
		Object.Size = UDim2.new(1, 0, 1, 0)
		Object.BackgroundTransparency = 1
		Object.BorderSizePixel = 0
		Object.Image = ID
		Object.Parent = self.Container
	else
		Object = Instance.new("Sound")
		Object.Volume = 0
		Object.SoundId = ID
		Object.Parent = self.Container
		Object:Play()
	end
	
	local function Complete()
		self.Maid[ID] = nil
		self.Finished += 1
		
		if self.Finished >= self.Items then
			self.Maid:Destroy()
		end
	end
	
	if Object.IsLoaded == false then
		self.Maid[ID] = RunService.Heartbeat:Connect(function()
			if Object.IsLoaded == true then
				Complete()
			end
		end)
	else
		Complete()
	end
end

function Preload:Add(Data)
	if typeof(Data.Images) == "table" then
		for _, PreItem in Data.Images do
			local Item = PreItem
			
			if typeof(PreItem) == "Instance" then
				Item = PreItem.Image
			end
			
			self:_Add(Item, "Image")
		end
	end
	
	if typeof(Data.Sounds) == "table" then
		for _, PreItem in Data.Sounds do
			local Item = PreItem

			if typeof(PreItem) == "Instance" then
				Item = PreItem.SoundId
			end

			self:_Add(Item, "Sound")
		end
	end
end

-- Destructor

function Preload:Destroy()
	self.Maid:Destroy()
	setmetatable(self, nil)
end

return Preload
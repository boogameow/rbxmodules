local MemoryService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Messaging = game:GetService("MessagingService")

local PartnerService = setmetatable({}, {})
PartnerService.__index = PartnerService
PartnerService.ClassName = "PartnerService"

PartnerService.SubscriptionName = "PartnerSearch"
PartnerService.Timeout = 600

local MemoryStore = MemoryService:GetSortedMap(PartnerService.SubscriptionName)

function PartnerService.new(Goal, Place)
	local self = setmetatable({}, PartnerService)

	self.Goal = Goal
	self.Place = Place or game.PlaceId

	self.Searching = false
	self.Frozen = false

	local Reserve, PrivateId = TeleportService:ReserveServer(self.Place)

	self.MyReserveCode = Reserve
	self.PrivateId = PrivateId

	self.Result = Instance.new("BindableEvent")
	self.Freeze = Instance.new("BindableEvent")

	game:BindToClose(function()
		pcall(function()
			self:Destroy()
		end)
	end)

	return self
end

function PartnerService:Cancel()
	if self.Frozen == true then
		self.Freeze:Wait()
	end

	if self.Searching == false then
		return
	end

	self.Frozen = true
	self.Searching = false

	local MyReserveCode = self.MyReserveCode

	local function Try()
		local Worked, Err = pcall(function()
			MemoryStore:UpdateAsync(self.Goal, function(Data)
				if typeof(Data) == "table" and Data.ReserveCode == MyReserveCode then
					Data.Found = true
					return Data
				end

				return nil
			end, self.Timeout)
		end)

		return Worked, Err
	end

	local Worked, Err = Try()

	if Worked ~= true then
		while task.wait(3) do
			Worked, Err = Try()
			warn(Worked, Err)

			if Worked == true then
				break
			end
		end
	end

	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	self.Frozen = false
	self.Freeze:Fire()

	self.ReserveCode = self.MyReserveCode
	self.Result:Fire(false)
end

function PartnerService:Found()
	if self.Searching == false then
		return
	end

	self.Searching = false

	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	self.Result:Fire(true)
end

function PartnerService:Search()
	if self.Frozen == true then
		self.Freeze:Wait()
	end

	if self.Searching == true then
		self.Result:Fire(false)
		return
	end

	self.Searching = true
	self.ReserveCode = nil

	local Worked, Connection = pcall(function()
		return Messaging:SubscribeAsync(self.SubscriptionName, function(Data)
			Data = Data.Data

			if self.Searching == true and Data.ReserveCode == self.MyReserveCode then
				self.ReserveCode = self.MyReserveCode
				self:Found()
			end
		end)
	end)

	if not Worked then
		self.Searching = false
		self.Result:Fire(false)
		warn("Messaging Failure:", Worked, Connection)
		return
	end

	self.Connection = Connection

	local Found = false

	local function Try()
		local Worked, Err = pcall(function()
			MemoryStore:UpdateAsync(self.Goal, function(Data)
				if not Data or Data.Found == true then
					return {
						Found = false,
						ReserveCode = self.MyReserveCode
					}
				elseif Data.Found == false then
					self.ReserveCode = Data.ReserveCode

					Data.Found = true
					Found = true
					return Data
				end

				return
			end, self.Timeout)
		end)

		return Worked, Err
	end

	local Worked, Err = Try()

	if not Worked then
		local Tries = 0

		while Tries < 3 do
			task.wait(3)

			Tries += 1
			Worked, Err = Try()

			if Worked then
				break
			end
		end

		if not Worked then
			if self.Connection then
				self.Connection:Disconnect()
				self.Connection = nil
			end

			self.Searching = false
			self.Result:Fire(false)
			warn("Memory Store Failure:", Err)
			return
		end
	end

	if Found == true then
		task.spawn(function()
			local Sub, Data = self.SubscriptionName, {["ReserveCode"] = self.ReserveCode}

			local function Try()
				local Success = pcall(function()
					Messaging:PublishAsync(Sub, Data)
				end)

				return Success
			end

			while true do
				local Success = Try()

				if Success then
					break
				end
				
				task.wait(3)
			end
		end)

		self:Found()
	else
		task.delay(self.Timeout, function()
			pcall(function()
				if self.Searching == true and self.Connection == Connection then
					self:Cancel()
				end
			end)
		end)
	end
end

function PartnerService:Destroy()
	self:Cancel()

	self.Result:Destroy()
	self.Freeze:Destroy()

	setmetatable(self, nil)
end

return PartnerService
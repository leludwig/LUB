-- LUB: code-built controls replacing the upstream asset dependency.
local runtime = getgenv().LUBRuntime
local stuff = {}
local colors = {
    background = Color3.fromRGB(17, 21, 30), card = Color3.fromRGB(28, 34, 46),
    text = Color3.fromRGB(239, 243, 249), muted = Color3.fromRGB(151, 163, 183),
    accent = Color3.fromRGB(108, 225, 181), border = Color3.fromRGB(48, 58, 76),
}
stuff.colors = colors

function stuff:Create(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end

function stuff:Round(object, radius)
    self:Create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
end

local function ordered(object, parent)
    object.LayoutOrder = #parent:GetChildren()
    object.Parent = parent
    return object
end

local function invoke(callback, value)
    local ok, err = pcall(callback, value)
    if not ok then warn("LUB: " .. tostring(err)) end
end

function stuff:Label(text, parent)
    local label = self:Create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28),
        AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Gotham,
        Text = text, TextSize = 13, TextColor3 = colors.muted,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    })
    return ordered(label, parent)
end

function stuff:Button(text, parent, callback)
    local button = self:Create("TextButton", {
        BackgroundColor3 = colors.card, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44), Font = Enum.Font.GothamMedium,
        Text = text, TextSize = 13, TextColor3 = colors.text,
    })
    self:Round(button)
    ordered(button, parent)
    button.Activated:Connect(function() invoke(callback) end)
    return button
end

-- Initial callbacks cannot overwrite a newer click or a mutually exclusive mode.
function stuff:Toggle(text, parent, default, callback)
    local button = self:Button("", parent, function() end)
    self:Create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -92, 1, 0), Font = Enum.Font.GothamMedium,
        Text = text, TextSize = 13, TextColor3 = colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, button)
    local indicator = self:Create("TextLabel", {
        Position = UDim2.new(1, -68, 0.5, -13), Size = UDim2.fromOffset(54, 26),
        Font = Enum.Font.GothamBold, TextSize = 11, BorderSizePixel = 0,
    }, button)
    self:Round(indicator, 13)
    local control = { Value = default == true, Instance = button, revision = 0 }
    function control:Set(value, silent)
        self.Value = value == true
        self.revision = self.revision + 1
        indicator.Text = self.Value and "ON" or "OFF"
        indicator.BackgroundColor3 = self.Value and colors.accent or colors.border
        indicator.TextColor3 = self.Value and colors.background or colors.muted
        if not silent then invoke(callback, self.Value) end
    end
    control:Set(control.Value, true)
    button.Activated:Connect(function() control:Set(not control.Value) end)
    local initialRevision = control.revision
    task.defer(function()
        if runtime.alive and control.revision == initialRevision then invoke(callback, control.Value) end
    end)
    return control
end

function stuff:Textbox(text, parent, default, callback)
    self:Label(text, parent)
    local box = self:Create("TextBox", {
        BackgroundColor3 = colors.card, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42), Font = Enum.Font.Gotham,
        Text = tostring(default or ""), TextSize = 13, TextColor3 = colors.text,
        PlaceholderColor3 = colors.muted, ClearTextOnFocus = false,
    })
    self:Round(box)
    ordered(box, parent)
    box.FocusLost:Connect(function() invoke(callback, box.Text) end)
    return box
end

function stuff:Unsupported(parent, callback)
    self:Label("This game has no LUB module yet. Choose a game from Games List.", parent)
    self:Button("Open Games List", parent, callback)
end

function stuff:addGame(parent, name, status, callback)
    local button = self:Button(name .. "   " .. (status or ""), parent, callback)
    button.Name = "GameElement"
    button:SetAttribute("SearchText", name:lower())
    return button
end

function stuff:Searchbar(parent)
    local box = self:Textbox("Search games", parent, "", function() end)
    box.PlaceholderText = "Type a game name..."
    box:GetPropertyChangedSignal("Text"):Connect(function()
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "GameElement" then
                child.Visible = string.find(child:GetAttribute("SearchText"), box.Text:lower(), 1, true) ~= nil
            end
        end
    end)
    return box
end

function stuff:CredHead(parent, text) return self:Label(text, parent) end
function stuff:CredPerson(parent, text) return self:Label(text, parent) end
return stuff

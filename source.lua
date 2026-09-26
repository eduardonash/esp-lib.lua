--[[

    esp-lib.lua
    A library for creating esp visuals in roblox using drawing.
    Provides functions to add boxes, health bars, names and distances to instances.
    Written by tul (@.lutyeh).

]]

-- // table
local options = ... or {}
local esplib = options.settings or (not options.isolated and getgenv().esplib)
if not esplib then
    esplib = {
        box = {
            enabled = true,
            type = "normal", -- normal, corner
            padding = 1.15,
            fill = Color3.new(1,1,1),
            outline = Color3.new(0,0,0),
        },
        healthbar = {
            enabled = true,
            fill = Color3.new(0,1,0),
            outline = Color3.new(0,0,0),
        },
        name = {
            enabled = true,
            fill = Color3.new(1,1,1),
            size = 13,
        },
        distance = {
            enabled = true,
            fill = Color3.new(1,1,1),
            size = 13,
        },
        tracer = {
            enabled = true,
            fill = Color3.new(1,1,1),
            outline = Color3.new(0,0,0),
            from = "mouse", -- mouse, head, top, bottom, center
        },
    }
    if not options.isolated then getgenv().esplib = esplib end
end

local espinstances = {}
local espfunctions = {}

-- // services
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera

-- // functions
-- Cache direct body parts; accessories/tools need not distort player bounds.
local bodycache = setmetatable({}, { __mode = "k" })
local signs = {
    Vector3.new(-1,-1,-1), Vector3.new(-1,-1,1),
    Vector3.new(-1,1,-1), Vector3.new(-1,1,1),
    Vector3.new(1,-1,-1), Vector3.new(1,-1,1),
    Vector3.new(1,1,-1), Vector3.new(1,1,1)
}
local function get_bounding_box(instance)
    local parts, root
    if instance:IsA("BasePart") then
        parts, root = { instance }, instance
    elseif instance:IsA("Model") then
        local cached = bodycache[instance]
        if not cached or os.clock() >= cached.nextScan then
            cached = { parts = {}, nextScan = os.clock() + 0.5 }
            for _, part in ipairs(instance:GetChildren()) do
                if part:IsA("BasePart") then
                    cached.parts[#cached.parts + 1] = part
                elseif not options.excludeAccessories and part:IsA("Accessory") then
                    local handle = part:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then cached.parts[#cached.parts + 1] = handle end
                end
            end
            bodycache[instance] = cached
        end
        parts = cached.parts
        root = instance:FindFirstChild("HumanoidRootPart") or instance.PrimaryPart or parts[1]
    end
    if not root or not root.Parent then return Vector2.zero, Vector2.zero, false end
    local frame = root.CFrame
    local low, high = Vector3.new(math.huge,math.huge,math.huge), Vector3.new(-math.huge,-math.huge,-math.huge)
    local count = 0
    for _, part in ipairs(parts) do
        if part.Parent then
            local cf = frame:ToObjectSpace(part.CFrame)
            local half = part.Size * 0.5
            local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
            local extent = Vector3.new(
                math.abs(r.X)*half.X + math.abs(u.X)*half.Y + math.abs(l.X)*half.Z,
                math.abs(r.Y)*half.X + math.abs(u.Y)*half.Y + math.abs(l.Y)*half.Z,
                math.abs(r.Z)*half.X + math.abs(u.Z)*half.Y + math.abs(l.Z)*half.Z)
            low, high = low:Min(cf.Position-extent), high:Max(cf.Position+extent)
            count = count + 1
        end
    end
    if count == 0 then return Vector2.zero, Vector2.zero, false end
    local center = (low+high)*0.5
    local half = (high-low)*0.5*math.max(1, esplib.box.padding or 1)
    local min, max = Vector2.new(math.huge,math.huge), Vector2.new(-math.huge,-math.huge)
    for _, sign in ipairs(signs) do
        local point = frame:PointToWorldSpace(center + half*sign)
        local projected = camera:WorldToViewportPoint(point)
        -- Hide near-plane intersections instead of generating enormous boxes.
        if projected.Z <= 0.1 then return Vector2.zero, Vector2.zero, false end
        local pixel = Vector2.new(projected.X, projected.Y)
        -- Offscreen corners still contribute: don't chop off heads/feet.
        min, max = min:Min(pixel), max:Max(pixel)
    end
    local view = camera.ViewportSize
    return min, max, max.X >= 0 and max.Y >= 0 and min.X <= view.X and min.Y <= view.Y
end

function espfunctions.add_box(instance)
    if not instance or espinstances[instance] and espinstances[instance].box then return end

    local box = {}

    local outline = Drawing.new("Square")
    outline.Thickness = 3
    outline.Filled = false
    outline.Transparency = 1
    outline.Visible = false

    local fill = Drawing.new("Square")
    fill.Thickness = 1
    fill.Filled = false
    fill.Transparency = 1
    fill.Visible = false

    box.outline = outline
    box.fill = fill

    box.corner_fill = {}
    box.corner_outline = {}
    for i = 1, (options.disableCorners and 0 or 8) do
        local outline = Drawing.new("Line")
        outline.Thickness = 3
        outline.Transparency = 1
        outline.Visible = false

        local fill = Drawing.new("Line")
        fill.Thickness = 1
        fill.Transparency = 1
        fill.Visible = false
        table.insert(box.corner_fill, fill)

        table.insert(box.corner_outline, outline)
    end

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].box = box
end

function espfunctions.add_healthbar(instance)
    if not instance or espinstances[instance] and espinstances[instance].healthbar then return end
    local outline = Drawing.new("Square")
    outline.Thickness = 1
    outline.Filled = true
    outline.Transparency = 1

    local fill = Drawing.new("Square")
    fill.Filled = true
    fill.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].healthbar = {
        outline = outline,
        fill = fill,
    }
end

function espfunctions.add_name(instance)
    if not instance or espinstances[instance] and espinstances[instance].name then return end
    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.Font = 1
    text.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].name = text
end

function espfunctions.add_distance(instance)
    if not instance or espinstances[instance] and espinstances[instance].distance then return end
    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.Font = 1
    text.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].distance = text
end

function espfunctions.add_tracer(instance)
    if not instance or espinstances[instance] and espinstances[instance].tracer then return end
    local outline = Drawing.new("Line")
    outline.Thickness = 3
    outline.Transparency = 1

    local fill = Drawing.new("Line")
    fill.Thickness = 1
    fill.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].tracer = {
        outline = outline,
        fill = fill,
    }
end

-- // main thread
local renderConnection
function espfunctions.update(currentCamera)
    camera = currentCamera or workspace.CurrentCamera
    if not camera then return end
    for instance, data in pairs(espinstances) do
        if not instance or not instance.Parent then
            if data.box then
                data.box.outline:Remove()
                data.box.fill:Remove()
                for _, line in ipairs(data.box.corner_fill) do
                    line:Remove()
                end
                for _, line in ipairs(data.box.corner_outline) do
                    line:Remove()
                end
            end
            if data.healthbar then
                data.healthbar.outline:Remove()
                data.healthbar.fill:Remove()
            end
            if data.name then
                data.name:Remove()
            end
            if data.distance then
                data.distance:Remove()
            end
            if data.tracer then
                data.tracer.outline:Remove()
                data.tracer.fill:Remove()
            end
            espinstances[instance] = nil
            bodycache[instance] = nil
            continue
        end

        local min, max, onscreen = get_bounding_box(instance)

        if data.box then
            local box = data.box

            if esplib.box.enabled and onscreen then
                local x, y = min.X, min.Y
                local w, h = (max - min).X, (max - min).Y
                local len = math.min(w, h) * 0.25

                if esplib.box.type == "normal" then
                    box.outline.Position = min
                    box.outline.Size = max - min
                    box.outline.Color = esplib.box.outline
                    box.outline.Visible = true

                    box.fill.Position = min
                    box.fill.Size = max - min
                    box.fill.Color = esplib.box.fill
                    box.fill.Visible = true

                    for _, line in ipairs(box.corner_fill) do
                        line.Visible = false
                    end
                    for _, line in ipairs(box.corner_outline) do
                        line.Visible = false
                    end

                elseif esplib.box.type == "corner" and #box.corner_fill == 8 then
                    local fill_lines = box.corner_fill
                    local outline_lines = box.corner_outline
                    local fill_color = esplib.box.fill
                    local outline_color = esplib.box.outline

                    local corners = {
                        { Vector2.new(x, y), Vector2.new(x + len, y) },
                        { Vector2.new(x, y), Vector2.new(x, y + len) },

                        { Vector2.new(x + w - len, y), Vector2.new(x + w, y) },
                        { Vector2.new(x + w, y), Vector2.new(x + w, y + len) },

                        { Vector2.new(x, y + h), Vector2.new(x + len, y + h) },
                        { Vector2.new(x, y + h - len), Vector2.new(x, y + h) },

                        { Vector2.new(x + w - len, y + h), Vector2.new(x + w, y + h) },
                        { Vector2.new(x + w, y + h - len), Vector2.new(x + w, y + h) },
                    }

                    for i = 1, 8 do
                        local from, to = corners[i][1], corners[i][2]
                        local dir = (to - from).Unit
                        local oFrom = from - dir
                        local oTo = to + dir

                        local o = outline_lines[i]
                        o.From = oFrom
                        o.To = oTo
                        o.Color = outline_color
                        o.Visible = true

                        local f = fill_lines[i]
                        f.From = from
                        f.To = to
                        f.Color = fill_color
                        f.Visible = true
                    end

                    box.outline.Visible = false
                    box.fill.Visible = false
                end
            else
                box.outline.Visible = false
                box.fill.Visible = false
                for _, line in ipairs(box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(box.corner_outline) do
                    line.Visible = false
                end
            end
        end

        if data.healthbar then
            local outline, fill = data.healthbar.outline, data.healthbar.fill

            if not esplib.healthbar.enabled or not onscreen then
                outline.Visible = false
                fill.Visible = false
            else
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local height = max.Y - min.Y
                    local padding = 1
                    local x = min.X - 3 - 1 - padding
                    local y = min.Y - padding
                    local health = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                    local fillheight = height * health

                    outline.Color = esplib.healthbar.outline
                    outline.Position = Vector2.new(x, y)
                    outline.Size = Vector2.new(1 + 2 * padding, height + 2 * padding)
                    outline.Visible = true

                    fill.Color = esplib.healthbar.fill
                    fill.Position = Vector2.new(x + padding, y + (height + padding) - fillheight)
                    fill.Size = Vector2.new(1, fillheight)
                    fill.Visible = true
                else
                    outline.Visible = false
                    fill.Visible = false
                end
            end
        end

        if data.name then
            if esplib.name.enabled and onscreen then
                local text = data.name
                local center_x = (min.X + max.X) / 2
                local y = min.Y - esplib.name.size - 3

                local name_str = instance.Name
                local humanoid = instance:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local player = players:GetPlayerFromCharacter(instance)
                    if player then
                        name_str = player.Name
                    end
                end

                text.Text = name_str
                text.Size = esplib.name.size
                text.Color = esplib.name.fill
                text.Position = Vector2.new(center_x, y)
                text.Visible = true
            else
                data.name.Visible = false
            end
        end

        if data.distance then
            if esplib.distance.enabled and onscreen then
                local text = data.distance
                local center_x = (min.X + max.X) / 2
                local y = max.Y + 5
                local dist
                if instance:IsA("Model") then
                    if instance.PrimaryPart then
                        dist = (camera.CFrame.Position - instance.PrimaryPart.Position).Magnitude
                    else
                        local part = instance:FindFirstChildWhichIsA("BasePart")
                        if part then
                            dist = (camera.CFrame.Position - part.Position).Magnitude
                        else
                            dist = 999
                        end
                    end
                else
                    dist = (camera.CFrame.Position - instance.Position).Magnitude
                end
                text.Text = tostring(math.floor(dist)) .. "m"
                text.Size = esplib.distance.size
                text.Color = esplib.distance.fill
                text.Position = Vector2.new(center_x, y)
                text.Visible = true
            else
                data.distance.Visible = false
            end
        end

        if data.tracer then
            if esplib.tracer.enabled and onscreen then
                local outline, fill = data.tracer.outline, data.tracer.fill

                local from_pos = Vector2.new()
                local to_pos = Vector2.new()

                if esplib.tracer.from == "mouse" then
                    local mouse_location = user_input_service:GetMouseLocation()
                    from_pos = Vector2.new(mouse_location.X, mouse_location.Y)
                elseif esplib.tracer.from == "head" then
                    local head = instance:FindFirstChild("Head")
                    if head then
                        local pos, visible = camera:WorldToViewportPoint(head.Position)
                        if visible then
                            from_pos = Vector2.new(pos.X, pos.Y)
                        else
                            from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                        end
                    else
                        from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                    end
                elseif esplib.tracer.from == "bottom" then
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                elseif esplib.tracer.from == "center" then
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                else
                    from_pos = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
                end

                to_pos = (min + max) / 2

                outline.From = from_pos
                outline.To = to_pos
                outline.Color = esplib.tracer.outline
                outline.Visible = true

                fill.From = from_pos
                fill.To = to_pos
                fill.Color = esplib.tracer.fill
                fill.Visible = true
            else
                data.tracer.outline.Visible = false
                data.tracer.fill.Visible = false
            end
        end
    end
end

function espfunctions.remove(instance)
    local data = espinstances[instance]
    if not data then return end
    if data.box then
        data.box.outline:Remove(); data.box.fill:Remove()
        for _, line in ipairs(data.box.corner_fill) do line:Remove() end
        for _, line in ipairs(data.box.corner_outline) do line:Remove() end
    end
    if data.healthbar then data.healthbar.outline:Remove(); data.healthbar.fill:Remove() end
    if data.name then data.name:Remove() end
    if data.distance then data.distance:Remove() end
    if data.tracer then data.tracer.outline:Remove(); data.tracer.fill:Remove() end
    espinstances[instance], bodycache[instance] = nil, nil
end

function espfunctions.unload()
    if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
    for instance in pairs(espinstances) do espfunctions.remove(instance) end
end

espfunctions.get_bounds = function(instance, currentCamera)
    camera = currentCamera or workspace.CurrentCamera
    if not camera then return Vector2.zero, Vector2.zero, false end
    return get_bounding_box(instance)
end
if not options.manualUpdate then
    renderConnection = run_service.RenderStepped:Connect(function() espfunctions.update() end)
end

-- // return
for k, v in pairs(espfunctions) do
    esplib[k] = v
end

return esplib

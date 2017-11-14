local file = nil
local canvas = nil
local shader = nil
local code = {"float sdModel(vec3 pos)",
"{",
"  return pos.y;",
"}"}
local cursor_pos = {x=1, y=1}
local font = nil
local time = 0

function drawCodeWindow()
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle("fill",0,0,love.graphics.getWidth()/3,love.graphics.getHeight())
  love.graphics.setColor(0.25, 0.25, 0.25, 1)
  love.graphics.line(love.graphics.getWidth()/3, 0, love.graphics.getWidth()/3, love.graphics.getHeight())
  -- local y = 5
  for i, line in ipairs(code) do
    local y = (i-1)*15 + 5
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf(tostring(i)..".", 5, y, 50, "left")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(line, 20, y, love.graphics.getWidth(), "left")
    if i == cursor_pos.y then
      if time % 10 < 5 then
        local x = cursor_pos.x*7 + 20
        -- local my = cursor_pos.y*15 - 10
        love.graphics.line(x, y, x, y+13)
      end
    end
    -- y = y + 15
  end
end

function updateCode()
  file = io.open("shaders/tmp.glsl", "w+")
  for _,line in ipairs(code) do
    file:write(line .. "\n")
  end
  file:write("\n")
  for line in io.lines("shaders/fragment.glsl") do
    file:write(line.."\n")
  end
  file:flush()
  file:close()
  shader = love.graphics.newShader("shaders/tmp.glsl")
end

function love.load()
  love.keyboard.setKeyRepeat(true)

  font = love.graphics.newFont("fonts/Bitstream Vera Sans Mono Roman.ttf", 12)
  love.graphics.setFont(font)

  updateCode()
end

function love.draw()
  love.graphics.setShader(shader)
  love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())
  love.graphics.setShader()

  drawCodeWindow()
end

function love.quit()
end

function love.update(dt)
  time = time + dt*10
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then
    cursor_pos.y = math.floor((y + 10)/15)
    if cursor_pos.y > #code then
      cursor_pos.y = #code
    end
    if cursor_pos.y < 1 then
      cursor_pos.y = 1
    end
    cursor_pos.x = math.floor((x - 20)/7)
    if cursor_pos.x > #code[cursor_pos.y] then
      cursor_pos.x = #code[cursor_pos.y]
    elseif cursor_pos.x < 0 then
      cursor_pos.x = 0
    end
  end
end

function love.keypressed(key, scancode, isrepeat)
  if key == "left" then
    if cursor_pos.x > 0 then
      cursor_pos.x = cursor_pos.x - 1
    elseif cursor_pos.y > 1 then
      cursor_pos.y = cursor_pos.y - 1
      cursor_pos.x = #code[cursor_pos.y]
    end
  elseif key == "right" then
    if cursor_pos.x < #code[cursor_pos.y] then
      cursor_pos.x = cursor_pos.x + 1
    elseif cursor_pos.y < #code then
      cursor_pos.y = cursor_pos.y + 1
      cursor_pos.x = 1
    end
  end
  if key == "up" then
    if cursor_pos.y > 1 then
      cursor_pos.y = cursor_pos.y - 1
      if cursor_pos.x > #code[cursor_pos.y] then
        cursor_pos.x = #code[cursor_pos.y]
      end
    end
  elseif key == "down" then
    if cursor_pos.y < #code then
      cursor_pos.y = cursor_pos.y + 1
      if cursor_pos.x > #code[cursor_pos.y] then
        cursor_pos.x = #code[cursor_pos.y]
      end
    end
  end
  if key == "backspace" then
    if cursor_pos.x > 0 then
      local str = code[cursor_pos.y]
      code[cursor_pos.y] = ""
      local offset = 0
      for i = 1, #str do
        local c = str:sub(i,i)
        if i ~= cursor_pos.x then
          code[cursor_pos.y] = code[cursor_pos.y] .. c
        else
          offset = offset + 1
        end
      end
      cursor_pos.x = cursor_pos.x - offset
    else
      if cursor_pos.y > 1 then
        local l = #code[cursor_pos.y - 1]
        code[cursor_pos.y - 1] = code[cursor_pos.y - 1] .. code[cursor_pos.y]
        table.remove(code, cursor_pos.y)
        cursor_pos.y = cursor_pos.y - 1
        cursor_pos.x = l
      end
    end
  end
  if key == "return" then
    if cursor_pos.x < #code[cursor_pos.y] then
      local str = code[cursor_pos.y]
      local line1 = ""
      local line2 = ""
      for i=1, #str do
        local c = str:sub(i,i)
        if i < cursor_pos.x+1 then
          line1 = line1 .. c
        else
          line2 = line2 .. c
        end
      end
      code[cursor_pos.y] = line2
      table.insert(code, cursor_pos.y, line1)
      cursor_pos.y = cursor_pos.y + 1
      cursor_pos.x = 0
    end
  end
end

function love.textinput(t)
  if cursor_pos.x > 0 then
    local str = code[cursor_pos.y]
    code[cursor_pos.y] = ""
    local offset = 0
    for i = 1, #str do
      local c = str:sub(i,i)
      if i == cursor_pos.x then
        c = c .. t
        offset = offset + 1
      end
      code[cursor_pos.y] = code[cursor_pos.y] .. c
    end
    cursor_pos.x = cursor_pos.x + offset
  else
    code[cursor_pos.y] = t .. code[cursor_pos.y]
    cursor_pos.x = cursor_pos.x + 1
  end
end

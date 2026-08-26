local Device = require("device")
local Screen = Device.screen

local Extractor = {}

function Extractor:getPageText(ui, page_no)
    if not ui or not ui.document then
        return nil
    end

    local full_text = nil

    -- Safe Method 1: Screen position text extraction (Primary for EPUB, MOBI, TXT)
    pcall(function()
        if ui.document.getTextFromPositions and Screen then
            local res = ui.document:getTextFromPositions(
                { x = 0, y = 0 },
                { x = Screen:getWidth(), y = Screen:getHeight() },
                true
            )
            if res and res.text and #res.text > 0 then
                full_text = res.text
            end
        end
    end)

    -- Safe Method 2: Page-based text box extraction (Fallback for PDF / DjVu)
    if not full_text or #full_text < 5 then
        pcall(function()
            if ui.document.getPageText then
                local text_table = ui.document:getPageText(page_no)
                if text_table and type(text_table) == "table" and #text_table > 0 then
                    local text_parts = {}
                    for _, box in ipairs(text_table) do
                        if box and box.text then
                            local clean_box = box.text:gsub("^%s+", ""):gsub("%s+$", "")
                            if #clean_box > 0 then
                                table.insert(text_parts, clean_box)
                            end
                        end
                    end
                    full_text = table.concat(text_parts, " ")
                elseif type(text_table) == "string" and #text_table > 0 then
                    full_text = text_table
                end
            end
        end)
    end

    if not full_text then
        return nil
    end

    -- Clean multiple whitespace & newlines
    full_text = full_text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    if #full_text < 5 then
        return nil
    end

    return full_text
end

return Extractor

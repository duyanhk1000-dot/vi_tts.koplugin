local Extractor = {}

function Extractor:getPageText(ui, page_no)
    if not ui or not ui.document then
        return nil
    end

    local text_table = ui.document:getPageText(page_no)
    if not text_table or type(text_table) ~= "table" or #text_table == 0 then
        return nil
    end

    -- Reconstruct paragraphs from KOReader text boxes
    local text_parts = {}
    for _, box in ipairs(text_table) do
        if box and box.text then
            local clean_box = box.text:gsub("^%s+", ""):gsub("%s+$", "")
            if #clean_box > 0 then
                table.insert(text_parts, clean_box)
            end
        end
    end

    local full_text = table.concat(text_parts, " ")
    -- Clean multiple whitespace
    full_text = full_text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    if #full_text < 5 then
        return nil
    end

    return full_text
end

return Extractor

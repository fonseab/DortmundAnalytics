module DortmundAnalytics

using HTTP, Gumbo, Cascadia, DataFrames, CSV

const DORTMUND_URL = "https://www.transfermarkt.com/borussia-dortmund/transfers/verein/16"

function get_page(url)
    headers = ["User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"]
    resp = HTTP.get(url, headers)
    parsehtml(String(resp.body))
end

function scrape_transfers()
    html = get_page(DORTMUND_URL)
    rows = eachmatch(Selector("table.items tbody tr"), html.root)
    
    records = []
    for row in rows
        cells = eachmatch(Selector("td"), row)
        length(cells) < 12 && continue
        push!(records, (
            name     = strip(nodeText(cells[4])),
            position = strip(nodeText(cells[5])),
            age      = strip(nodeText(cells[6])),
            club     = strip(nodeText(cells[10])),
            fee      = strip(nodeText(cells[12])),
        ))
    end
    
    DataFrame(records)
end
function inspect_page()
    html = get_page(DORTMUND_URL)
    rows = eachmatch(Selector("table.items tbody tr"), html.root)
    for (i, row) in enumerate(rows[1:3])
        println("=== ROW $i ===")
        cells = eachmatch(Selector("td"), row)
        for (j, cell) in enumerate(cells)
            println("  cell $j: ", nodeText(cell))
        end
    end
end

end
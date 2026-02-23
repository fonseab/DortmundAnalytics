module DortmundAnalytics

using HTTP, Gumbo, Cascadia, DataFrames, CSV, Plots, Statistics

const BASE_URL = "https://www.transfermarkt.com/borussia-dortmund/transfers/verein/16/saison_id/"

function get_page(url)
    headers = ["User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"]
    resp = HTTP.get(url, headers)
    parsehtml(String(resp.body))
end

function scrape_season(season::Int)
    html = get_page(BASE_URL * string(season))
    tables = eachmatch(Selector("table.items"), html.root)

    length(tables) < 2 && return []

    records = []
    for (direction, table) in zip(["in", "out"], tables[1:2])
        rows = eachmatch(Selector("tbody tr"), table)
        for row in rows
            cells = eachmatch(Selector("td"), row)
            length(cells) < 12 && continue
            push!(records, (
                season    = season,
                direction = direction,
                name      = strip(nodeText(cells[4])),
                position  = strip(nodeText(cells[5])),
                age       = strip(nodeText(cells[6])),
                club      = strip(nodeText(cells[10])),
                fee       = strip(nodeText(cells[12])),
            ))
        end
    end
    records
end

function scrape_all_seasons(from::Int=2010, to::Int=2024)
    all_records = []
    for season in from:to
        println("Scraping $season...")
        append!(all_records, scrape_season(season))
        sleep(2)
    end
    DataFrame(all_records)
end

function parse_fee(fee::AbstractString)
    fee = strip(fee)
    fee == "-" && return (type = "unknown", value = missing)
    startswith(fee, "End of loan") && return (type = "loan_return", value = missing)
    fee == "loan transfer" && return (type = "loan", value = missing)
    fee == "free transfer" && return (type = "free", value = missing)

    m = match(r"€([\d.]+)(m|k)?", fee)
    m === nothing && return (type = "unknown", value = missing)

    value = parse(Float64, m[1])
    value = m[2] == "k" ? value / 1000 : value
    return (type = "transfer", value = value)
end

function clean_transfers(df::DataFrame)
    parsed = parse_fee.(df.fee)
    df = copy(df)
    df.fee_type  = [p.type for p in parsed]
    df.fee_value = [p.value for p in parsed]
    df
end

function player_roi(df::DataFrame)
    bought = filter(row -> row.direction == "in" && row.fee_type == "transfer", df)
    sold   = filter(row -> row.direction == "out" && row.fee_type == "transfer", df)

    bought = select(bought, :name, :season => :season_in, :age => :age_in, :fee_value => :cost)
    sold   = select(sold,   :name, :season => :season_out, :age => :age_out, :fee_value => :revenue)

    sold = combine(groupby(sold, :name),
        :season_out => maximum => :season_out,
        :age_out    => maximum => :age_out,
        :revenue    => maximum => :revenue)

    joined = innerjoin(bought, sold, on=:name)
    joined = filter(row -> row.season_out > row.season_in, joined)

    joined.roi     = joined.revenue .- joined.cost
    joined.roi_pct = (joined.revenue .- joined.cost) ./ joined.cost .* 100

    sort(joined, :roi, rev=true)
end

function plot_revenue(by_season::DataFrame)
    plot(by_season.season, by_season.total_revenue,
        label="Transfer Revenue (€m)",
        xlabel="Season",
        ylabel="€ millions",
        title="BVB Outgoing Transfer Revenue 2010-2024",
        lw=2, marker=:circle)
end

function plot_net_spend(net::DataFrame)
    net = sort(net, :season)
    bar(net.season, net.net_spend,
        label="Net Spend (€m)",
        xlabel="Season",
        ylabel="€ millions",
        title="BVB Net Transfer Spend 2010-2024",
        color=ifelse.(net.net_spend .>= 0, :green, :red))
end

function plot_roi(roi::DataFrame)
    scatter(roi.age_in, roi.roi,
        xlabel="Age at Acquisition",
        ylabel="ROI (€m)",
        title="BVB Player ROI by Age at Acquisition",
        legend=false,
        color=ifelse.(roi.roi .>= 0, :green, :red),
        marker=:circle, ms=6)
end
function holding_period_analysis(roi::DataFrame)
    df = copy(roi)
    df.years_held = df.season_out .- df.season_in
    
    by_period = combine(groupby(df, :years_held),
        :roi     => mean => :avg_roi,
        :roi_pct => mean => :avg_roi_pct,
        :roi     => length => :n_players)

    sort(by_period, :years_held)
end

function plot_holding_period(hp::DataFrame)
    bar(hp.years_held, hp.avg_roi,
        xlabel="Years Held",
        ylabel="Average ROI (€m)",
        title="BVB Average ROI by Holding Period",
        label="Avg ROI (€m)",
        color=ifelse.(hp.avg_roi .>= 0, :green, :red))
end
end

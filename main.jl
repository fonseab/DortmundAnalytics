include("src/DortmundAnalytics.jl")
using CSV, DataFrames, Statistics, Plots
cd(expanduser("~/DortmundAnalytics"))

df_raw        = CSV.read("data/transfers_all_seasons.csv", DataFrame)
df            = DortmundAnalytics.clean_transfers(df_raw)
outgoing      = filter(row -> row.direction == "out" && row.fee_type == "transfer", df)
incoming      = filter(row -> row.direction == "in"  && row.fee_type == "transfer", df)
out_by_season = combine(groupby(outgoing, :season), :fee_value => sum => :revenue)
in_by_season  = combine(groupby(incoming, :season), :fee_value => sum => :spent)
net           = outerjoin(out_by_season, in_by_season, on=:season)
net.net_spend = net.revenue .- net.spent
roi           = DortmundAnalytics.player_roi(df)

println("Data loaded. Available: df, outgoing, incoming, net, roi")

require "./lib/rg_rack"
use Rack::Static, :urls => ["/stylesheets"], :root => "public"
run Racker

require "./*"
require "http/server"

# Colony implementation in Crystal
module CrystalColony
  VERSION = "0.1.0"


  world = World.new 214, 120
  world.smooth_topology
  queen = Queen.new world, 1

  puts "Starting server"

  server = HTTP::Server.new([HTTP::StaticFileHandler.new("static/")]) do |context|
    context.response.content_type = "text/json"

    puts "Incoming request for non-static endpoint: " + context.request.path

    if context.request.path == "/world"
      context.response.print world.get_world_view
    elsif context.request.path == "/smooth"
      context.response.print world.smooth_topology
    elsif context.request.path == "/evolve"
      world.evolve_topology
      context.response.print world.smooth_topology
    elsif context.request.path == "/reset"
      world = World.new 214, 120
      world.smooth_topology
      queen = Queen.new world, 60
      context.response.print "reset"
    elsif context.request.path == "/pickpoints"
      context.response.print world.pick_points
    elsif context.request.path == "/startsim"
      queen = Queen.new world, 60
      context.response.print queen.start_sim
    elsif context.request.path == "/ticksim"
      world.tick_sim
      context.response.print queen.tick_sim
    elsif context.request.path == "/getpop"
      context.response.print queen.get_population_json
    elsif context.request.path == "/getall"
      pop = queen.get_population_json
      wld = world.get_world_view
      context.response.print [wld,pop].to_json
    end

  end

  address = server.bind_tcp 8080
  puts "Listening on http://#{address}"
  server.listen
  puts "Done listening"
end

require "./*"
require "http/server"

# Colony implementation in Crystal
module CrystalColony
  VERSION = "0.1.0"
  POP_SIZE = 40
  x_size = 214
  y_size = 120
  #x_size = 100
  #y_size = 100
  world = World.new x_size, y_size
  world.smooth_topology
  queen = Queen.new world, 1

  puts "Starting server"

  server = HTTP::Server.new([HTTP::StaticFileHandler.new("static/")]) do |context|
    context.response.content_type = "text/json"

    if context.request.path == "/world"
      context.response.print world.get_world_view
    elsif context.request.path == "/smooth"
      context.response.print world.smooth_topology
    elsif context.request.path == "/evolve"
      world.evolve_topology
      context.response.print world.smooth_topology
    elsif context.request.path == "/reset"
      world = World.new x_size, y_size
      world.smooth_topology
      queen = Queen.new world, POP_SIZE
    elsif context.request.path == "/pickpoints"
      context.response.print world.pick_points
    elsif context.request.path == "/startsim"
      queen = Queen.new world, POP_SIZE
      context.response.print queen.start_sim
    elsif context.request.path == "/ticksim"
      world.tick_sim
      context.response.print queen.tick_sim
    elsif context.request.path == "/getpop"
      context.response.print queen.get_population_json
    elsif context.request.path == "/tickpop"
      world.tick_sim
      queen.tick_sim
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

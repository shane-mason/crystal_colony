require "json"

class Queen

  property population_size
  property world
  property population
  property tick_count

  def initialize(@world : World, @population_size : Int32)
    @tick_count = 0
    @population = Array(Agent).new(@population_size)
  end

  def start_sim()
    puts "Starting sim"
    @population = Array(Agent).new()
    i = 0
    spawn_tile = @world.get_spawn_tile
    @tick_count = 0
    agent = Agent.new spawn_tile, @world.x_size, @world.y_size
    @population.push agent
    puts "Done starting"
  end

  def tick_sim()

    if @population.size < @population_size && Random.rand < 0.1
      a = Agent.new @world.get_spawn_tile, @world.x_size, @world.y_size
      @population.push a
      b = population.size
    end

    @tick_count += 1
    puts @tick_count
    reaped = Array(Agent).new()


    @population.each do |a|
      if a.tick_age >= 500
        reaped.push a
      elsif a.returned == true
        #note: need to save genetics to use in next generation
        reaped.push a
      else
        a.tick
      end
    end

    reaped.each do |to_reap|
      @population.delete(to_reap)
    end

  end

  def get_population_json
    return @population.to_json
  end

end

require "json"

class Agent
  include JSON::Serializable
  @[JSON::Field(ignore: true)]
  property tile
  property x
  property y
  property loaded
  @[JSON::Field(ignore: true)]
  property x_boundary
  @[JSON::Field(ignore: true)]
  property y_boundary
  @[JSON::Field(ignore: true)]
  property dir_count
  @[JSON::Field(ignore: true)]
  property elevation_threshhold
  @[JSON::Field(ignore: true)]
  property randomness
  @[JSON::Field(ignore: true)]
  property turn_weights
  @[JSON::Field(ignore: true)]
  property track : Array(Tile)
  @[JSON::Field(ignore: true)]
  property pheromones : Array(Tile)
  @[JSON::Field(ignore: true)]
  property tick_age
  @[JSON::Field(ignore: true)]
  property returned

  def initialize( @tile : Tile, @x_boundary : Int32, @y_boundary : Int32 )
    @last_dir = 0
    @last_dir = Random.rand(8)
    @x = tile.x
    @y = tile.y
    @elevation_threshhold = 50
    @randomness = 0.1
    #left, right direction weights
    @turn_weights = {0.5, 0.5}
    @dir_count = 8
    @loaded = false
    @track = Array(Tile).new()
    @pheromones = Array(Tile).new()
    @pheromone_level = 0
    @pheromone_attraction = 0.95
    @pheromone_blocker = 0.0
    @pheromone_blocker_decay = 0.1
    @tick_age = 0
    @returned = false

    fuzz_genetics
  end

  def fuzz_genetics

    if Random.rand > 0.5
      @elevation_threshhold += Random.rand 10
    else
      @elevation_threshhold -= Random.rand 10
    end

    if Random.rand > 0.5
      left = @turn_weights[0] + Random.rand 0.1
      right = 1 - left
      @turn_weights = {left, right}
    else
      left = @turn_weights[0] - Random.rand 0.1
      right = 1 - left
      @turn_weights = {left, right}
    end

    if Random.rand > 0.5
      @randomness += Random.rand 0.1
    else
      @randomness -= Random.rand 0.1
    end

    if Random.rand > 0.5
      @pheromone_attraction += Random.rand 0.05
    else
      @pheromone_attraction -= Random.rand 0.05
    end

  end


  def tick
    @tick_age+=1
    if @pheromone_blocker > 0
      @pheromone_blocker-=@pheromone_blocker_decay
    end
    if @loaded == true

      if @track.size > 0
        if @tile.pheromone < @pheromone_level
          @tile.pheromone = @pheromone_level
        end
        @pheromones.push(@tile)
        @pheromone_level -= 1
        next_tile = @track.pop

        #test if we've been here before
        first_visited = @track.index(@tile)
        if first_visited && first_visited >= 0 && first_visited < @track.size - 1
          @track = @track.first(first_visited)
        end

        @x = next_tile.x
        @y = next_tile.y
        @tile = next_tile
      else
        @returned = true

      end
    else
      pick_next
    end
  end


  def pick_next

    #first - check for pheromone levels
    max_pheromone_dir = get_highest_pheromone
    if @pheromone_blocker <= 0 && max_pheromone_dir[0] > -1 && max_pheromone_dir[1] > @tile.pheromone
      #then we should go that way
      new_dir = max_pheromone_dir[0]

      if @tile.costs[new_dir] > @elevation_threshhold
        @pheromone_blocker = 1
        #then this means that this path isn't valid
        valid_path = false
        tc = 0
        while valid_path==false && tc < dir_count
          new_dir = shift_dir @last_dir
          if @tile.costs[new_dir] < @elevation_threshhold
            valid_path = true
          end
          tc+=1
        end

      end
    else

      if @tile.costs[@last_dir] > @elevation_threshhold
        new_dir = get_min_cost_dir
      elsif randomness > Random.rand
        new_dir = shift_dir @last_dir
      else
        # assume same direction initially
        new_dir = @last_dir
      end
    end


    # is the new tile a border tile?
    if @tile.neighbors[new_dir].neighbors.size == 0
        new_dir = reverse_dir(@last_dir)
        #don't move until next tick
    else
      @tile = @tile.neighbors[new_dir]
      @track.push(@tile)
      if @tile.target == true
        @loaded = true
        @pheromone_level = 250
      end
      @x = @tile.x
      @y = @tile.y
    end


      @last_dir = new_dir
  end

  def shift_dir(dir)
    new_dir = dir
    if @turn_weights[0] > Random.rand
      #then left turn
      new_dir -= 1
    else
      new_dir += 1
    end

    if new_dir < 0
      new_dir = dir_count + new_dir
    elsif new_dir >= dir_count
      new_dir = new_dir - dir_count
    end
    return new_dir
  end

  def reverse_dir(dir)
    reversed = dir + Random.rand((dir_count/2).to_i) + 2
    if reversed >= dir_count
      reversed = reversed - dir_count
    end
    return reversed
  end

  def get_min_cost_dir()
    i = 0
    min = -1
    min_val = 250.0
    while i < @tile.costs.size
      if @tile.costs[i] < min_val
        min = i
        min_val = @tile.costs[i]
      end
      i+=1
    end
    return min
  end

  def get_highest_pheromone()
    i = 0
    max_i = -1
    max_val = 0
    while i < dir_count
      if @tile.neighbors[i].pheromone > max_val
        max_i = i
        max_val = @tile.neighbors[i].pheromone
      end
      i+=1
    end
    return {max_i, max_val}
  end


end

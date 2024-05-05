require "json"
require "../../crystal_brain/src/crystal_brain"

class Tile
  include JSON::Serializable
  property height : Int32
  property target : Bool
  property colony : Bool
  @[JSON::Field(ignore: true)]
  property neighbors : Array(Tile)
  @[JSON::Field(ignore: true)]
  property costs : Array(Float64)
  property x : Int32
  property y : Int32
  property pheromone : Float64

  def initialize(x : Int32, y : Int32, height : Int32)
    @height = height
    @target = false
    @colony = false
    # order: ne n nw e w se s sw
    @costs = Array(Float64).new(8, 0.0)
    @neighbors = Array(Tile).new(8)
    @x = x
    @y = y
    @pheromone = 0.0
  end

  def initialize()
    @height = 0
    @target = false
    @colony = false
    # order: ne n nw e w se s sw
    @costs = Array(Float64).new(8, 0.0)
    @neighbors = Array(Tile).new(8)
    @x = 0
    @y = 0
    @pheromone = 0.0
  end

end

class NeighborhoodStats
  property count
  property average_height
  property cumulative_height

  def initialize()
    @count = 0
    @average_height = 0
    @cumulative_height = 0
  end

end

class World
  property x_size : Int32
  property y_size : Int32
  property max_height
  property low_mark
  property high_mark
  property colony_boundary
  property target_boundary
  property point_buffer
  property colony_spawn
  property brain

  def initialize(size_x : Int32, size_y : Int32)
    @x_size = size_x
    @y_size = size_y
    @board = Array(Array(Tile)).new(@x_size) { Array(Tile).new(@y_size, Tile.new) }
    @max_height = 255
    @low_mark = 200
    @high_mark = 200
    @colony_boundary = 20
    @target_boundary = 20
    @point_buffer = 4
    @colony_spawn = {0,0}
    @brain = CrystalBrain::Brain.new "test", @x_size, @y_size
    generate_livetopo()
    #generate_topology()
  end

  def reset()
    puts "resetting"
    @brain = CrystalBrain::Brain.new "test", @x_size, @y_size
    @board = Array(Array(Tile)).new(@x_size) { Array(Tile).new(@y_size, Tile.new) }
    generate_livetopo()
    #generate_topology()
  end

  def get_spawn_tile
    return @board[@colony_spawn[0]][@colony_spawn[1]]
  end

  def calc_costs
    spinner = [{-1,-1},{0,-1},{1,-1},{-1,0}, {1,0}, {1,1}, {0,1}, {-1,1}]
    x = 1
    while x < @x_size-1
      y = 1
      while y < @y_size-1
        count = 0
        spinner.each do |c|
          height_diff =  @board[x+c[0]][y+c[1]].height - @board[x][y].height
          @board[x][y].costs[count] = height_diff.to_f
          @board[x][y].neighbors.push(@board[x+c[0]][y+c[1]])
          count+=1
        end
        y+=1
      end
      x+=1
    end
  end

  def get_neihborhood_stats(x_in, y_in)
    neighborhood = NeighborhoodStats.new
    [-1, 0, 1].each do |x|
      [-1, 0, 1].each do |y|
        unless x == 0 && y == 0
          this_x = x_in + x
          this_y = y_in + y
          if this_x >= 0 && this_x < @x_size && this_y >= 0 && this_y < @y_size
            neighborhood.count += 1
            neighborhood.cumulative_height += @board[this_x][this_y].height
          end
        end
      end
    end
    neighborhood.average_height = (neighborhood.cumulative_height/neighborhood.count).to_i
    return neighborhood
  end

  def generate_livetopo()
     #just copy for now
     (0...@x_size).each do |x|
      (0...@y_size).each do |y|
        tile = Tile.new( x, y, @brain.@board[x][y] * 127)
        @board[x][y] = tile
      end
     end
     calc_costs
  end

  def evolve_topology()
    @brain.tick()
    (0...@x_size).each do |x|
      (0...@y_size).each do |y|
        @board[x][y].height = brain.@board[x][y] * 127
      end
     end
     calc_costs
  end

  def smooth_topology()
    rnd = Random.new
    (0...@x_size).each do |x|
      (0...@y_size).each do |y|
        neighborhood = get_neihborhood_stats(x,y)
        average = neighborhood.average_height
        #get diff from average
        diff = average - @board[x][y].height
        change = 0.0
        if diff > 10
          change = diff
        end
        @board[x][y].height = @board[x][y].height  + change.to_i
        y+=1
      end
      x+=1
    end
    #@board = new_board
    calc_costs
  end

  def pick_points
    pick_target_points
    pick_colony_points
  end

  def pick_target_points

    @board.each do |row|
      row.each do |cell|
        cell.target = false
      end
    end

    rnd = Random.new
    target_point_found = false

    while !target_point_found

      test_x = @point_buffer + rnd.rand(@x_size-@point_buffer*2)
      test_y = @point_buffer + rnd.rand(@target_boundary-@point_buffer*2)
      avg = get_neihborhood_stats(test_x, test_y)
      if avg.average_height < @low_mark/2

        start_y = test_y - rnd.rand(@point_buffer-1) - 1
        end_y = test_y + rnd.rand(@point_buffer-1) + 1
        y = start_y

        while y < end_y

          start_x = test_x - rnd.rand(@point_buffer-1) - 1
          end_x = test_x + rnd.rand(@point_buffer-1) + 1
          x = start_x
          while x < end_x
            @board[x.to_i][y.to_i].target = true
            x+=1
          end
          y+=1
        end
        target_point_found = true
      end
    end

  end

  def pick_colony_points

    @board.each do |row|
      row.each do |cell|
        cell.colony = false
      end
    end

    rnd = Random.new
    target_point_found = false

    while !target_point_found

      test_x = @point_buffer + rnd.rand(@x_size-@point_buffer*2)
      test_y = @y_size - (@point_buffer + rnd.rand(@target_boundary-@point_buffer*2))
      avg = get_neihborhood_stats(test_x, test_y)

      if avg.average_height < @low_mark/2
        @colony_spawn = {test_x,test_y}
        start_y = test_y - @point_buffer/2
        end_y = test_y + @point_buffer/2 - 1
        y = start_y

        while y < end_y
          start_x = test_x - @point_buffer/2
          end_x = test_x + @point_buffer/2 -1
          x = start_x
          while x < end_x
            @board[x.to_i][y.to_i].colony = true
            x+=1
          end
          y+=1
        end
        target_point_found = true
      end
    end

  end

  def tick_sim
    @board.each do |row|
      row.each do |cell|
        if cell.pheromone > 0
          cell.pheromone -= 0.5
        end
      end
    end
  end

  def get_world_view
    return @board.to_json
  end

end

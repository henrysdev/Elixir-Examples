defmodule Main do
  def main do
    eh_pid = spawn(EventHandler, :listen, [%{}])
    spawn(Plane, :init, ["ABC123", "New York", eh_pid])
  end
end

#--------------------------------------------------------------------------------
# The business logic and target state we will keep track of using event sourcing
#--------------------------------------------------------------------------------
defmodule Plane do
  defstruct id: "", location: nil, miles: 0

  def init(id, location, eh_pid) do
    %Plane{id: id, location: location} |> demo(eh_pid)
  end
  def fly(%Plane{location: origin_name, id: id} = plane, dest_name, eh_pid) do
    # build a flight for the given destination
    flight = %Flight{
      origin: origin_name,
      dest: dest_name,
      dist: Utils.calc_miles(
        Map.fetch!(Const.geo_locations, origin_name),
        Map.fetch!(Const.geo_locations, dest_name))
    }
    # declare an anon function to represent the actual state change
    apply_fn = fn plane, flight ->
      %Plane{id: plane.id, location: flight.dest, miles: plane.miles + flight.dist} end
    # pass record of event to our EventHandler + apply
    send eh_pid, {:event, id, flight, apply_fn}
    apply_fn.(plane, flight)
  end
  def demo(plane, eh_pid) do
    plane
    |> fly("Chicago", eh_pid)
    |> fly("Baltimore", eh_pid)
    |> fly("Boston", eh_pid)
    |> fly("Philadelphia", eh_pid)
    send eh_pid, {:replay, plane.id}
  end
end

#--------------------------------------------------------------------------------
# The kind of event that will define state changes to our Plane
#--------------------------------------------------------------------------------
defmodule Flight do
  defstruct origin: nil, dest: nil, dist: 0
end

#--------------------------------------------------------------------------------
# Handles everything in the event-sourcing abstraction layer
#--------------------------------------------------------------------------------
defmodule EventHandler do
  def listen(state_changes) do
    receive do
      {:event, id, flight, apply} -> listen event_change(state_changes, id, {flight, apply})
      {:replay, id} -> replay_changes(state_changes, id) |> IO.inspect()
      {:view, id}   -> view_changes(state_changes, id) |> IO.inspect()
    end
    listen state_changes
  end
  def event_change(state, id, {flight, apply}) do
    event = %EventRecord{apply: apply, state: flight}
    Map.update(state, id, [event], &[event|&1])
  end
  def replay_changes(state_changes, id) do
    Map.fetch!(state_changes, id)
    |> List.foldr(%Plane{id: id, location: nil, miles: 0},
      fn %EventRecord{apply: f, state: state}, acc -> f.(acc, state) end)
  end
  def view_changes(state_changes, id) do
    Map.fetch!(state_changes, id)
    |> Enum.reverse()
  end
end

#--------------------------------------------------------------------------------
# The structure of a state change that is persisted (and replayable)
#--------------------------------------------------------------------------------
defmodule EventRecord do
  defstruct apply: nil, state: nil
end


defmodule Const do
  def geo_locations do
    %{
      "New York" => {40.6943, -73.9249},
      "Chicago" => {41.8373, -87.6861},
      "Washington D.C." => {38.9047, -77.0163},
      "Baltimore" => {39.3051, -76.6144},
      "Philadelphia" => {32.7761, -89.1221},
      "Boston" => {42.3188, -71.0846},
      "Pittsburgh" => {40.4396, -79.9763},
    }
  end
end
defmodule Utils do
  def calc_miles({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow((y2 - y1), 2)) * 55
  end
end

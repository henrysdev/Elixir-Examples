defmodule Master do
  @doc "listen for messages from worker processes"
  def listen(t_start, workers \\ []) do
    receive do
      {:register, w_pid} -> listen(t_start, [w_pid | workers])
      {:done, t_end}     -> finished(t_start, t_end, workers)
    end
    listen(t_start, workers)
  end
  @doc "print the shortest time taken for the magic number
  to be guessed before terminating all worker processes"
  def finished(t_start, t_end, workers) do
    IO.puts "Time to Find Magic Number: #{t_end - t_start}ms"
    Enum.map(workers, &Process.exit(&1, :kill))
  end
end

defmodule Worker do
  @doc "choose a random integer in the specified range until
  the magic number is chosen"
  def guess(number, range, master_pid) do 
    if :rand.uniform(range) == number do
      send master_pid, {:done, System.monotonic_time(:millisecond)}
    else
      guess(number, range, master_pid)
    end
  end
end

defmodule Main do
  @doc "spawn and register workers with master"
  def init_workers(0, _magic_num, _range, _master_pid), do: :ok
  def init_workers(unspawned, magic_num, range, master_pid)do
    w_pid = spawn(Worker, :guess, [magic_num, range, master_pid])
    send master_pid, {:register, w_pid}
    init_workers(unspawned - 1, magic_num, range, master_pid)
  end
  @doc "get program parameters before spawning master
  and worker processes"
  def main do
    {magic_num, _}    = (IO.gets "Magic Number (Int): ") |> Integer.parse
    {worker_count, _} = (IO.gets "Worker Count (Int): ") |> Integer.parse
    {range, _}        = (IO.gets "Guess Range (Int): ")  |> Integer.parse
    master_pid = spawn(Master, :listen, [System.monotonic_time(:millisecond)])
    init_workers(worker_count, magic_num, range, master_pid)
  end
end
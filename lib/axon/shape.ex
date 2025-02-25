defmodule Axon.Shape do
  @moduledoc false

  # Collection of shape calculations for calculating the
  # output and trainable parameter shapes for high-level
  # layers.
  #
  # `nil` is often used as a stand-in for unknown batch
  # size, so each of these methods must account for that.

  ## Linear

  @doc """
  Calculates the shape of a dense kernel given the input
  shape and output units.

  ## Examples

      iex> Axon.Shape.dense_kernel({nil, 784}, 128)
      {784, 128}

      iex> Axon.Shape.dense_kernel({nil, 128}, 256)
      {128, 256}

      iex> Axon.Shape.dense_kernel({nil, 3, 256, 256}, 128)
      {256, 128}
  """
  def dense_kernel(input_shape, units) do
    {elem(input_shape, Nx.rank(input_shape) - 1), units}
  end

  @doc """
  Calculates the shape of a dense bias given the input
  shape and output units.

  ## Examples

      iex> Axon.Shape.dense_bias({nil, 784}, 128)
      {1, 128}

      iex> Axon.Shape.dense_bias({nil, 128}, 256)
      {1, 256}

      iex> Axon.Shape.dense_bias({nil, 3, 256, 256}, 128)
      {1, 128}
  """
  def dense_bias(_input_shape, units) do
    {1, units}
  end

  @doc """
  Calculates the output shape of a dense layer given the
  input shape and output units.

  ## Examples

      iex> Axon.Shape.dense({nil, 784}, 128)
      {nil, 128}

      iex> Axon.Shape.dense({nil, 256}, 512)
      {nil, 512}

      iex> Axon.Shape.dense({nil, 128}, 128)
      {nil, 128}
  """
  def dense(input_shape, units) do
    {elem(input_shape, 0), units}
  end

  ## Conv

  @doc """
  Calculates the shape of a convolution kernel given the
  input shape, output filters, and kernel size.

  Kernel size must match the number of spatial dimensions
  in the input (input rank - 2).

  ## Examples

      iex> Axon.Shape.conv_kernel({nil, 3, 224, 224}, 32, {3, 3})
      {32, 3, 3, 3}

      iex> Axon.Shape.conv_kernel({nil, 3, 28}, 64, {2})
      {64, 3, 2}

      iex> Axon.Shape.conv_kernel({nil, 1, 32, 32, 10}, 32, {2, 1, 3})
      {32, 1, 2, 1, 3}

  ### Error cases

      iex> Axon.Shape.conv_kernel({nil, 1, 28, 28}, 32, {2})
      ** (ArgumentError) kernel size must have same rank (1) as number of spatial dimensions in the input (2)
  """
  def conv_kernel(input_shape, output_filters, kernel_size) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    input_channels = elem(input_shape, 1)
    List.to_tuple([output_filters, input_channels | Tuple.to_list(kernel_size)])
  end

  @doc """
  Calculates the shape of a convolution bias given the
  input shape, output filters, and kernel size.

  Kernel size must match the number of spatial dimensions
  in the input (input rank - 2).

  ## Examples

      iex> Axon.Shape.conv_bias({nil, 3, 224, 224}, 32, {3, 3})
      {1, 32, 1, 1}

      iex> Axon.Shape.conv_bias({nil, 3, 28}, 64, {2})
      {1, 64, 1}

      iex> Axon.Shape.conv_bias({nil, 1, 32, 32, 10}, 32, {2, 1, 3})
      {1, 32, 1, 1, 1}

  ### Error cases

      iex> Axon.Shape.conv_bias({nil, 1, 28, 28}, 32, {2})
      ** (ArgumentError) kernel size must have same rank (1) as number of spatial dimensions in the input (2)
  """
  def conv_bias(input_shape, output_filters, kernel_size) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    spatial_dims = List.duplicate(1, Nx.rank(input_shape) - 2)
    List.to_tuple([1, output_filters | spatial_dims])
  end

  @doc """
  Calculates the shape after a convolution layer with
  the given parent shape, kernel shape, strides, padding,
  input dilation and kernel dilation.
  """
  def conv(parent_shape, kernel_shape, strides, padding, input_dilation, kernel_dilation) do
    permutation = [0, 1, 2, 3]
    names = List.duplicate(nil, Nx.rank(parent_shape))

    # Account for possibly nil batch dimension
    parent_shape =
      if elem(parent_shape, 0) do
        parent_shape
      else
        put_elem(parent_shape, 0, 1)
      end

    {shape, _, _} =
      Nx.Shape.conv(
        parent_shape,
        names,
        kernel_shape,
        names,
        strides,
        padding,
        1,
        1,
        input_dilation,
        kernel_dilation,
        permutation,
        permutation,
        permutation
      )

    shape
  end

  @doc """
  Calculates the shape of a depthwise convolution kernel given the
  input shape, output filters, and kernel size.

  Kernel size must match the number of spatial dimensions
  in the input (input rank - 2).

  ## Examples

      iex> Axon.Shape.depthwise_conv_kernel({nil, 3, 224, 224}, 3, {3, 3})
      {9, 1, 3, 3}

      iex> Axon.Shape.depthwise_conv_kernel({nil, 3, 28}, 2, {2})
      {6, 1, 2}

      iex> Axon.Shape.depthwise_conv_kernel({nil, 1, 32, 32, 10}, 1, {2, 1, 3})
      {1, 1, 2, 1, 3}

  ### Error cases

      iex> Axon.Shape.depthwise_conv_kernel({nil, 1, 28, 28}, 32, {2})
      ** (ArgumentError) kernel size must have same rank (1) as number of spatial dimensions in the input (2)
  """
  def depthwise_conv_kernel(input_shape, channel_multiplier, kernel_size) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    input_channels = elem(input_shape, 1)
    List.to_tuple([input_channels * channel_multiplier, 1 | Tuple.to_list(kernel_size)])
  end

  @doc """
  Calculates the shape of a convolution bias given the
  input shape, channel multiplier, and kernel size.

  Kernel size must match the number of spatial dimensions
  in the input (input rank - 2).

  ## Examples

      iex> Axon.Shape.depthwise_conv_bias({nil, 3, 224, 224}, 3, {3, 3})
      {1, 9, 1, 1}

      iex> Axon.Shape.depthwise_conv_bias({nil, 3, 28}, 2, {2})
      {1, 6, 1}

      iex> Axon.Shape.depthwise_conv_bias({nil, 1, 32, 32, 10}, 1, {2, 1, 3})
      {1, 1, 1, 1, 1}

  ### Error cases

      iex> Axon.Shape.depthwise_conv_bias({nil, 1, 28, 28}, 2, {2})
      ** (ArgumentError) kernel size must have same rank (1) as number of spatial dimensions in the input (2)
  """
  def depthwise_conv_bias(input_shape, channel_multiplier, kernel_size) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    input_channels = elem(input_shape, 1)
    spatial_dims = List.duplicate(1, Nx.rank(input_shape) - 2)
    List.to_tuple([1, input_channels * channel_multiplier | spatial_dims])
  end

  @doc """
  Calculates the shape after a depthwise convolution layer with
  the given parent shape, kernel shape, strides, padding, input
  dilation, and kernel dilation.
  """
  def depthwise_conv(
        parent_shape,
        kernel_shape,
        strides,
        padding,
        input_dilation,
        kernel_dilation
      ) do
    permutation = [0, 1, 2, 3]
    names = List.duplicate(nil, Nx.rank(parent_shape))

    # Account for possibly nil batch dimension
    parent_shape =
      if elem(parent_shape, 0) do
        parent_shape
      else
        put_elem(parent_shape, 0, 1)
      end

    input_channels = elem(parent_shape, 1)

    {shape, _, _} =
      Nx.Shape.conv(
        parent_shape,
        names,
        kernel_shape,
        names,
        strides,
        padding,
        input_channels,
        1,
        input_dilation,
        kernel_dilation,
        permutation,
        permutation,
        permutation
      )

    shape
  end

  @doc """
  Calculates the shape of a 2d depthwise separable convolution
  kernel given the input shape, channel multiplier, kernel size
  and parameter number.

  Kernel size must match the number of spatial dimensions
  in the input (input rank - 2).

  ## Examples

      iex> Axon.Shape.separable_conv2d_kernel({nil, 3, 32, 32}, 3, {3, 3}, 1)
      {9, 1, 3, 1}

      iex> Axon.Shape.separable_conv2d_kernel({nil, 3, 32, 32}, 3, {3, 3}, 2)
      {9, 1, 1, 3}

  ### Error cases

      iex> Axon.Shape.separable_conv2d_kernel({nil, 1, 28, 28}, 2, {2}, 1)
      ** (ArgumentError) kernel size must have same rank (1) as number of spatial dimensions in the input (2)
  """
  def separable_conv2d_kernel(input_shape, channel_multiplier, kernel_size, num) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    cond do
      num == 1 ->
        {elem(input_shape, 1) * channel_multiplier, 1, elem(kernel_size, 0), 1}

      num == 2 ->
        {elem(input_shape, 1) * channel_multiplier, 1, 1, elem(kernel_size, 1)}

      true ->
        raise ArgumentError, "invalid kernel number"
    end
  end

  @doc """
  Calculates the shape of a depthwise separable convolution
  bias given the input shape, channel multiplier and kernel size.

  Kernel size must match the number of spatial dimensions
  in the input (input rank - 2).

  ## Examples

      iex> Axon.Shape.separable_conv2d_bias({nil, 3, 32, 32}, 3, {3, 3})
      {1, 9, 1, 1}

      iex> Axon.Shape.separable_conv2d_bias({nil, 3, 32, 32}, 4, {3, 3})
      {1, 12, 1, 1}

  ### Error cases

      iex> Axon.Shape.separable_conv2d_bias({nil, 1, 28, 28}, 2, {2})
      ** (ArgumentError) kernel size must have same rank (1) as number of spatial dimensions in the input (2)
  """
  def separable_conv2d_bias(input_shape, channel_multiplier, kernel_size) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    {1, elem(input_shape, 1) * channel_multiplier, 1, 1}
  end

  @doc """
  Calculates the shape of a 3-d depthwise separable convolution
  kernel given the input shape, channel multiplier, kernel size,
  and parameter number.

  Kernel size must match the number of spatial dimensions
  in the input (input rank - 2).

  ## Examples

      iex> Axon.Shape.separable_conv3d_kernel({nil, 3, 32, 32, 3}, 3, {3, 3, 3}, 1)
      {9, 1, 3, 1, 1}

      iex> Axon.Shape.separable_conv3d_kernel({nil, 3, 32, 32, 3}, 4, {3, 3, 3}, 2)
      {12, 1, 1, 3, 1}

      iex> Axon.Shape.separable_conv3d_kernel({nil, 3, 32, 32, 3}, 4, {3, 3, 3}, 3)
      {12, 1, 1, 1, 3}

  ### Error cases

      iex> Axon.Shape.separable_conv2d_bias({nil, 1, 28, 28, 3}, 2, {2})
      ** (ArgumentError) kernel size must have same rank (1) as number of spatial dimensions in the input (3)
  """
  def separable_conv3d_kernel(input_shape, channel_multiplier, kernel_size, num) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    cond do
      num == 1 ->
        {elem(input_shape, 1) * channel_multiplier, 1, elem(kernel_size, 0), 1, 1}

      num == 2 ->
        {elem(input_shape, 1) * channel_multiplier, 1, 1, elem(kernel_size, 1), 1}

      num == 3 ->
        {elem(input_shape, 1) * channel_multiplier, 1, 1, 1, elem(kernel_size, 2)}
    end
  end

  @doc """
  Calculates the shape of a depthwise separable convolution
  bias.
  """
  def separable_conv3d_bias(input_shape, channel_multiplier, kernel_size) do
    unless Nx.rank(kernel_size) == Nx.rank(input_shape) - 2 do
      raise ArgumentError,
            "kernel size must have same rank (#{Nx.rank(kernel_size)})" <>
              " as number of spatial dimensions in the input (#{Nx.rank(input_shape) - 2})"
    end

    {1, elem(input_shape, 1) * channel_multiplier, 1, 1, 1}
  end

  @doc """
  Calculates the output shape after a pooling operation
  with the given parent shape, kernel size, strides, and
  padding.
  """
  def pool(parent_shape, kernel_size, strides, padding) do
    kernel_dilation = List.duplicate(1, Nx.rank(parent_shape))

    padding =
      if is_list(padding),
        do: [{0, 0}, {0, 0} | padding],
        else: padding

    kernel_size =
      kernel_size
      |> Tuple.insert_at(0, 1)
      |> Tuple.insert_at(0, 1)

    strides = [1, 1 | strides]

    {shape, _} =
      Nx.Shape.pool(
        parent_shape,
        kernel_size,
        strides,
        padding,
        kernel_dilation
      )

    shape
  end

  @doc """
  Calculates the output shape after an adaptive pooling operation
  with the given parent shape and output size.

  ## Examples

      iex> Axon.Shape.adaptive_pool({nil, 3, 32, 32}, {27, 27})
      {nil, 3, 27, 27}

      iex> Axon.Shape.adaptive_pool({nil, 1, 28, 28}, {25, 25})
      {nil, 1, 25, 25}

  ### Error cases

      iex> Axon.Shape.adaptive_pool({nil, 1, 28, 28}, {30, 30})
      ** (ArgumentError) invalid output size for adaptive pool operation for input with shape {nil, 1, 28, 28} and output size {30, 30} each dimension of output size must be greater than or equal to spatial dimension of input
  """
  def adaptive_pool(parent_shape, output_size) do
    valid_output_size? =
      parent_shape
      |> Tuple.delete_at(0)
      |> Tuple.delete_at(0)
      |> Tuple.to_list()
      |> Enum.zip(Tuple.to_list(output_size))
      |> Enum.all?(&(elem(&1, 0) >= elem(&1, 1)))

    unless valid_output_size? do
      raise ArgumentError,
            "invalid output size for adaptive pool operation for" <>
              " input with shape #{inspect(parent_shape)} and output" <>
              " size #{inspect(output_size)} each dimension" <>
              " of output size must be greater than or equal to spatial" <>
              " dimension of input"
    end

    List.to_tuple([elem(parent_shape, 0), elem(parent_shape, 1) | Tuple.to_list(output_size)])
  end

  @doc """
  Calculates the gamma/beta shape of a normalization layer
  given the input shape and channel index.

  ## Examples

      iex> Axon.Shape.norm_param({nil, 3, 28, 28}, 1)
      {1, 3, 1, 1}

      iex> Axon.Shape.norm_param({nil, 28, 28, 3}, 3)
      {1, 1, 1, 3}
  """
  def norm_param(parent_shape, channel_index) do
    parent_shape
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.map(fn {x, i} -> if i == channel_index, do: x, else: 1 end)
    |> List.to_tuple()
  end

  @doc """
  Calculates the shape after a flatten layer, which
  flattens the non-minibatch dimensions into a single
  dimension.

  ## Examples

      iex> Axon.Shape.flatten({nil, 1, 28, 28})
      {nil, 784}

      iex> Axon.Shape.flatten({nil, 128})
      {nil, 128}

      iex> Axon.Shape.flatten({nil, 10, 10})
      {nil, 100}

  ### Error cases

      iex> Axon.Shape.flatten({nil})
      ** (ArgumentError) expected flatten input shape to have at least rank 2, got {nil} with rank 1
  """
  def flatten(shape) do
    unless Nx.rank(shape) >= 2 do
      raise ArgumentError,
            "expected flatten input shape to have at least" <>
              " rank 2, got #{inspect(shape)} with rank #{Nx.rank(shape)}"
    end

    # Account for possibly `nil` batch dimension
    out_units =
      if elem(shape, 0) do
        div(Nx.size(shape), elem(shape, 0))
      else
        Nx.size(Tuple.delete_at(shape, 0))
      end

    {elem(shape, 0), out_units}
  end

  @doc """
  Calculates the shape after a concatenate layer, which
  concatenates inputs along the given dimension.

  ## Examples

      iex> Axon.Shape.concatenate([{nil, 32}, {nil, 12}], 1)
      {nil, 44}

      iex> Axon.Shape.concatenate([{nil, 24, 32}, {nil, 24, 15}, {nil, 24, 10}], 2)
      {nil, 24, 57}

  ### Error cases

      iex> Axon.Shape.concatenate([{10, 32}, {5, 32}], 1)
      ** (ArgumentError) non-concat dims must be equal got 5 and 10 while concatenating on axis 1
  """
  def concatenate([s1 | _] = input_shapes, axis) do
    nil_names = for _ <- 1..length(input_shapes), do: List.duplicate(nil, Nx.rank(s1))
    {shape, _} = Nx.Shape.concatenate(input_shapes, nil_names, axis)
    shape
  end
end

///|
priv struct Plane {
  width : Int32
  height : Int32
  samples : Array[Int32]
}

///|
fn Plane::at(self : Plane, x : Int32, y : Int32) -> Int32 {
  self.samples[y * self.width + x]
}

///|
fn clamp_index(value : Int32, size : Int32) -> Int32 {
  if value < 0 {
    0
  } else if value >= size {
    size - 1
  } else {
    value
  }
}

///|
fn box_upsample(
  source : Plane,
  h_ratio : Int32,
  v_ratio : Int32,
  width : Int32,
  height : Int32,
) -> Plane {
  let out = Array::make(width * height, 0)
  for y in 0..<height {
    for x in 0..<width {
      out[y * width + x] = source.at(x / h_ratio, y / v_ratio)
    }
  }
  { width, height, samples: out, }
}

///|
fn fancy_h2v1(source : Plane, width : Int32, height : Int32) -> Plane {
  let n = source.width
  let out = Array::make(n * 2 * height, 0)
  for y in 0..<height {
    let base = y * n * 2
    let first = source.at(0, y)
    out[base] = first
    out[base + 1] = (first * 3 + source.at(1, y) + 2) >> 2
    for x in 1..<(n - 1) {
      let value = source.at(x, y) * 3
      out[base + 2 * x] = (value + source.at(x - 1, y) + 1) >> 2
      out[base + 2 * x + 1] = (value + source.at(x + 1, y) + 2) >> 2
    }
    let last = source.at(n - 1, y)
    out[base + 2 * (n - 1)] = (last * 3 + source.at(n - 2, y) + 1) >> 2
    out[base + 2 * n - 1] = last
  }
  crop(out, n * 2, width, height)
}

///|
fn fancy_h2v2(source : Plane, width : Int32, height : Int32) -> Plane {
  let n = source.width
  let rows = source.height
  let out_width = n * 2
  let out = Array::make(out_width * rows * 2, 0)
  for out_row in 0..<(rows * 2) {
    let near = out_row / 2
    let far = clamp_index(
      if out_row % 2 == 0 {
        near - 1
      } else {
        near + 1
      },
      rows,
    )
    let base = out_row * out_width
    let column_sum = (x : Int32) => source.at(x, near) * 3 + source.at(x, far)
    let first = column_sum(0)
    out[base] = (first * 4 + 8) >> 4
    out[base + 1] = (first * 3 + column_sum(1) + 7) >> 4
    for x in 1..<(n - 1) {
      let this = column_sum(x)
      out[base + 2 * x] = (this * 3 + column_sum(x - 1) + 8) >> 4
      out[base + 2 * x + 1] = (this * 3 + column_sum(x + 1) + 7) >> 4
    }
    let last = column_sum(n - 1)
    out[base + 2 * (n - 1)] = (last * 3 + column_sum(n - 2) + 8) >> 4
    out[base + 2 * n - 1] = (last * 4 + 7) >> 4
  }
  crop(out, out_width, width, height)
}

///|
fn fancy_h1v2(source : Plane, width : Int32, height : Int32) -> Plane {
  let n = source.width
  let rows = source.height
  let out = Array::make(n * rows * 2, 0)
  for out_row in 0..<(rows * 2) {
    let near = out_row / 2
    let upper = out_row % 2 == 0
    let far = clamp_index(if upper { near - 1 } else { near + 1 }, rows)
    let bias = if upper { 1 } else { 2 }
    for x in 0..<n {
      out[out_row * n + x] = (source.at(x, near) * 3 + source.at(x, far) + bias) >>
        2
    }
  }
  crop(out, n, width, height)
}

///|
fn crop(
  samples : Array[Int32],
  stride : Int32,
  width : Int32,
  height : Int32,
) -> Plane {
  let out = Array::make(width * height, 0)
  for y in 0..<height {
    for x in 0..<width {
      out[y * width + x] = samples[y * stride + x]
    }
  }
  { width, height, samples: out, }
}

///|
fn upsample(
  source : Plane,
  h_ratio : Int32,
  v_ratio : Int32,
  width : Int32,
  height : Int32,
) -> Plane {
  if h_ratio == 1 && v_ratio == 1 {
    crop(source.samples, source.width, width, height)
  } else if h_ratio == 2 && v_ratio == 1 && source.width > 2 {
    fancy_h2v1(source, width, height)
  } else if h_ratio == 2 && v_ratio == 2 && source.width > 2 {
    fancy_h2v2(source, width, height)
  } else if h_ratio == 1 && v_ratio == 2 {
    fancy_h1v2(source, width, height)
  } else {
    box_upsample(source, h_ratio, v_ratio, width, height)
  }
}

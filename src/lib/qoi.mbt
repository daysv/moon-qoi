pub struct QoiHeader {
  width : UInt
  height : UInt
  channels : UInt
  colorspace : UInt
}

pub struct QoiColor {
  mut r : Byte
  mut g : Byte
  mut b : Byte
  mut a : Byte
}

let qoi_magic : UInt = 0x716f6966
let qoi_op_index : Byte = 0x00
let qoi_op_diff : Byte = 0x40
let qoi_op_luma : Byte = 0x80
let qoi_op_run : Byte = 0xc0
let qoi_op_rgb : Byte = 0xfe
let qoi_op_rgba : Byte = 0xff
let qoi_mask_2 : Byte = 0xc0
let qoi_padding : Array[Byte] = [0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]

fn qoi_color_hash(color : QoiColor) -> Int {
  let r = color.r.to_int()
  let g = color.g.to_int()
  let b = color.b.to_int()
  let a = color.a.to_int()
  (r * 3 + g * 5 + b * 7 + a * 11) % 64
}

fn read_u32_be(data : Array[Byte], offset : Int) -> UInt {
  let b0 = data[offset].to_uint()
  let b1 = data[offset + 1].to_uint()
  let b2 = data[offset + 2].to_uint()
  let b3 = data[offset + 3].to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

fn read_byte(data : Array[Byte], offset : Int) -> Byte {
  data[offset]
}

fn bytes_to_array(bytes : Bytes) -> Array[Byte] {
  let array = Array::new()
  let length = bytes.length()
  for i = 0; i < length; i = i + 1 {
    array.push(bytes[i])
  }
  array
}
///|
/// Decodes QOI (Quite OK Image) format data into image header information and
/// raw pixel data.
///
/// Parameters:
///
/// * `data` : The QOI-encoded image data as bytes.
///
/// Returns a `Result` containing a tuple of the decoded image header
/// (`QoiHeader`) and raw pixel data as a flat array of bytes on success, or an
/// error message string on failure. The pixel data is arranged as consecutive
/// RGB or RGBA values depending on the number of channels specified in the
/// header.
///
/// Example:
///
/// ```moonbit
/// let qoi_data = b"\x71\x6f\x69\x66\x00\x00\x00\x02\x00\x00\x00\x01\x03\x00\xfe\xff\x00\x00\xfe\x00\xff\x00\x00\x01\x00\x00\x00\x00\x00\x01"
/// match decode(qoi_data) {
///   Ok((header, pixels)) => {
///     println("Image size: \{header.width}x\{header.height}")
///     println("Channels: \{header.channels}")
///     println("Pixel count: \{pixels.length()}")
///     println("Pixel: \{pixels}")
///   }
///   Err(msg) => println("Decode failed: \{msg}")
/// }
/// ```
///
pub fn decode(b : Bytes) -> Result[(QoiHeader, Array[Byte]), String] {
  let data = bytes_to_array(b)
  if data.length() < 14 {
    return Err("Invalid QOI file: too short")
  }

  // Read header
  let magic = read_u32_be(data, 0)
  if magic != qoi_magic {
    return Err("Invalid QOI file: wrong magic number")
  }
  let width = read_u32_be(data, 4)
  let height = read_u32_be(data, 8)
  let channels = read_byte(data, 12).to_uint()
  let colorspace = read_byte(data, 13).to_uint()
  if channels != 3 && channels != 4 {
    return Err("Invalid QOI file: channels must be 3 or 4")
  }
  let header = QoiHeader::{ width, height, channels, colorspace }

  // Initialize decode state
  let pixels = Array::new()
  let index = Array::make(64, QoiColor::{ r: 0, g: 0, b: 0, a: 0 })
  let pixel = QoiColor::{ r: 0, g: 0, b: 0, a: 255 }
  let mut pos = 14
  let pixel_count = (width * height).reinterpret_as_int()
  let mut pixels_written = 0
  while pixels_written < pixel_count && pos < data.length() - 8 {
    let chunk = read_byte(data, pos)
    pos = pos + 1
    if chunk == qoi_op_rgb {
      pixel.r = read_byte(data, pos)
      pixel.g = read_byte(data, pos + 1)
      pixel.b = read_byte(data, pos + 2)
      pos = pos + 3
    } else if chunk == qoi_op_rgba {
      pixel.r = read_byte(data, pos)
      pixel.g = read_byte(data, pos + 1)
      pixel.b = read_byte(data, pos + 2)
      pixel.a = read_byte(data, pos + 3)
      pos = pos + 4
    } else if (chunk & qoi_mask_2) == qoi_op_index {
      let idx = chunk.to_int()
      pixel.r = index[idx].r
      pixel.g = index[idx].g
      pixel.b = index[idx].b
      pixel.a = index[idx].a
    } else if (chunk & qoi_mask_2) == qoi_op_diff {
      let dr = (chunk >> 4).land(0x03).to_int() - 2
      let dg = (chunk >> 2).land(0x03).to_int() - 2
      let db = chunk.land(0x03).to_int() - 2
      pixel.r = (pixel.r.to_int() + dr).land(0xff).to_byte()
      pixel.g = (pixel.g.to_int() + dg).land(0xff).to_byte()
      pixel.b = (pixel.b.to_int() + db).land(0xff).to_byte()
    } else if (chunk & qoi_mask_2) == qoi_op_luma {
      let chunk2 = read_byte(data, pos)
      pos = pos + 1
      let dg = chunk.land(0x3f).to_int() - 32
      let dr = dg + (chunk2 >> 4).to_int() - 8
      let db = dg + chunk2.land(0x0f).to_int() - 8
      pixel.r = (pixel.r.to_int() + dr).land(0xff).to_byte()
      pixel.g = (pixel.g.to_int() + dg).land(0xff).to_byte()
      pixel.b = (pixel.b.to_int() + db).land(0xff).to_byte()
    } else if (chunk & qoi_mask_2) == qoi_op_run {
      let run_length = chunk.land(0x3f).to_int() + 1
      for i = 0; i < run_length; i = i + 1 {
        pixels.push(pixel.r)
        pixels.push(pixel.g)
        pixels.push(pixel.b)
        if channels == 4 {
          pixels.push(pixel.a)
        }
        pixels_written = pixels_written + 1
      }
      let hash_idx = qoi_color_hash(pixel)
      index[hash_idx] = QoiColor::{
        r: pixel.r,
        g: pixel.g,
        b: pixel.b,
        a: pixel.a,
      }
      continue
    }

    // Store pixel in output
    pixels.push(pixel.r)
    pixels.push(pixel.g)
    pixels.push(pixel.b)
    if channels == 4 {
      pixels.push(pixel.a)
    }
    pixels_written = pixels_written + 1

    // Update index
    let hash_idx = qoi_color_hash(pixel)
    index[hash_idx] = QoiColor::{
      r: pixel.r,
      g: pixel.g,
      b: pixel.b,
      a: pixel.a,
    }
  }
  Ok((header, pixels))
}

fn write_u32_be(data : Array[Byte], offset : Int, value : UInt) -> Unit {
  data[offset] = (value >> 24).land(0xff).to_byte()
  data[offset + 1] = (value >> 16).land(0xff).to_byte()
  data[offset + 2] = (value >> 8).land(0xff).to_byte()
  data[offset + 3] = value.land(0xff).to_byte()
}
fn write_byte(data : Array[Byte], offset : Int, value : Byte) -> Unit {
  data[offset] = value
}
fn array_to_bytes(array : Array[Byte]) -> Bytes {
  Bytes::from_array(array)
}

///|
/// Encodes pixel data into the QOI (Quite OK Image) format.
///
/// Parameters:
///
/// * `header` : The QOI header containing image metadata including width,
///   height, number of channels (3 for RGB or 4 for RGBA), and colorspace
///   information.
/// * `pixels` : Raw pixel data as a flat array of bytes, where each pixel is
///   represented by 3 or 4 consecutive bytes (RGB or RGBA) depending on the
///   header's channel count.
///
/// Returns a `Result` containing the encoded QOI image data as `Bytes` on
/// success, or an error message string on failure.
///
/// Example:
///
/// ```moonbit
/// let header = QoiHeader::{ width: 2U, height: 1U, channels: 3U, colorspace: 0U }
/// let pixels = [b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00'] // Red, Green pixels
/// match encode(header, pixels) {
///   Ok(data) => println("Successfully encoded QOI data \{data}")
///   Err(msg) => println("Encoding failed: \{msg}")
/// }
/// ```
///
pub fn encode(
  header : QoiHeader,
  pixels : Array[Byte],
) -> Result[Bytes, String] {
  if header.channels != 3U && header.channels != 4U {
    return Err("Invalid channels: must be 3 or 4")
  }
  let pixel_count = (header.width * header.height).reinterpret_as_int()
  let expected_pixel_data_length = pixel_count *
    header.channels.reinterpret_as_int()
  if pixels.length() != expected_pixel_data_length {
    return Err("Invalid pixel data length")
  }

  // Pre-allocate array with header size (14 bytes)
  let output = Array::make(14, b'\x00')

  // Write header
  write_u32_be(output, 0, qoi_magic)
  write_u32_be(output, 4, header.width)
  write_u32_be(output, 8, header.height)
  write_byte(output, 12, header.channels.to_byte())
  write_byte(output, 13, header.colorspace.to_byte())

  // Initialize encoding state
  let index = Array::make(64, QoiColor::{ r: 0, g: 0, b: 0, a: 0 })
  let prev_pixel = QoiColor::{ r: 0, g: 0, b: 0, a: 255 }
  let mut pixel_pos = 0
  let mut run_length = 0
  for i = 0; i < pixel_count; i = i + 1 {
    let pixel = QoiColor::{
      r: pixels[pixel_pos],
      g: pixels[pixel_pos + 1],
      b: pixels[pixel_pos + 2],
      a: if header.channels == 4 {
        pixels[pixel_pos + 3]
      } else {
        b'\xFF'
      },
    }
    pixel_pos = pixel_pos + header.channels.reinterpret_as_int()
    if pixel.r == prev_pixel.r &&
      pixel.g == prev_pixel.g &&
      pixel.b == prev_pixel.b &&
      pixel.a == prev_pixel.a {
      run_length = run_length + 1
      if run_length == 62 || i == pixel_count - 1 {
        output.push(qoi_op_run | (run_length - 1).to_byte())
        run_length = 0
      }
    } else {
      if run_length > 0 {
        output.push(qoi_op_run | (run_length - 1).to_byte())
        run_length = 0
      }
      let hash_idx = qoi_color_hash(pixel)
      if index[hash_idx].r == pixel.r &&
        index[hash_idx].g == pixel.g &&
        index[hash_idx].b == pixel.b &&
        index[hash_idx].a == pixel.a {
        output.push(qoi_op_index | hash_idx.to_byte())
      } else {
        index[hash_idx] = QoiColor::{
          r: pixel.r,
          g: pixel.g,
          b: pixel.b,
          a: pixel.a,
        }
        if pixel.a == prev_pixel.a {
          let dr = pixel.r.to_int() - prev_pixel.r.to_int()
          let dg = pixel.g.to_int() - prev_pixel.g.to_int()
          let db = pixel.b.to_int() - prev_pixel.b.to_int()
          if dr >= -2 && dr <= 1 && dg >= -2 && dg <= 1 && db >= -2 && db <= 1 {
            let chunk = qoi_op_diff |
              ((dr + 2) << 4).to_byte() |
              ((dg + 2) << 2).to_byte() |
              (db + 2).to_byte()
            output.push(chunk)
          } else {
            let dr_dg = dr - dg
            let db_dg = db - dg
            if dg >= -32 &&
              dg <= 31 &&
              dr_dg >= -8 &&
              dr_dg <= 7 &&
              db_dg >= -8 &&
              db_dg <= 7 {
              let chunk1 = qoi_op_luma | (dg + 32).to_byte()
              let chunk2 = ((dr_dg + 8) << 4).lor(db_dg + 8).to_byte()
              output.push(chunk1)
              output.push(chunk2)
            } else {
              output.push(qoi_op_rgb)
              output.push(pixel.r)
              output.push(pixel.g)
              output.push(pixel.b)
            }
          }
        } else {
          output.push(qoi_op_rgba)
          output.push(pixel.r)
          output.push(pixel.g)
          output.push(pixel.b)
          output.push(pixel.a)
        }
      }
    }
    prev_pixel.r = pixel.r
    prev_pixel.g = pixel.g
    prev_pixel.b = pixel.b
    prev_pixel.a = pixel.a
  }

  // Write padding
  for i = 0; i < qoi_padding.length(); i = i + 1 {
    output.push(qoi_padding[i])
  }
  Ok(array_to_bytes(output))
}


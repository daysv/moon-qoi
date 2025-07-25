test "read_and_decode_image"{
  let target = @fs.read_file_to_bytes("resources/rgb_image.rgb")

  let bytes = @fs.read_file_to_bytes("resources/rgb_image.qoi")
    // Call decode function
  let result = decode(bytes)
  match result {
    Ok((_header, data)) => {
      assert_eq(Bytes::from_array(data), target)
    }
    Err(error) => {
      fail(error)
    }
  }
}

test "read_and_encode_image"{
  let target = @fs.read_file_to_bytes("resources/rgb_image.qoi")

  let bytes = @fs.read_file_to_bytes("resources/rgb_image.rgb")

  let header = QoiHeader::{
    width: 70U,
    height: 53U,
    channels: 3U,
    colorspace: 0U 
  }
 
  let result = encode(header, bytes.to_array())
  match result {
    Ok((data)) => {
      assert_eq(data, target)
    }
    Err(error) => {
      fail(error)
    }
  }
}

test "read_and_decode_image"{
  let target = @fs.read_file_to_bytes("resources/rgba_image.rgb")

  let bytes = @fs.read_file_to_bytes("resources/rgba_image.qoi")
    // Call decode function
  let result = decode(bytes)
  match result {
    Ok((_header, data)) => {
      assert_eq(Bytes::from_array(data), target)
    }
    Err(error) => {
      fail(error)
    }
  }
}

test "read_and_encode_image"{
  let target = @fs.read_file_to_bytes("resources/rgba_image.qoi")

  let bytes = @fs.read_file_to_bytes("resources/rgba_image.rgb")

  let header = QoiHeader::{
    width: 70U,
    height: 53U,
    channels: 4U,
    colorspace: 0U 
  }
 
  let result = encode(header, bytes.to_array())
  match result {
    Ok((data)) => {
      assert_eq(data, target)
    }
    Err(error) => {
      fail(error)
    }
  }
}

test (b: @bench.T) {
  let qoi_rgb = @fs.read_file_to_bytes("resources/rgb_image.qoi")

  let rgb = @fs.read_file_to_bytes("resources/rgb_image.rgb")

  let qoi_rgba = @fs.read_file_to_bytes("resources/rgba_image.qoi")

  let rgba = @fs.read_file_to_bytes("resources/rgba_image.rgb")

  let header = QoiHeader::{
    width: 70U,
    height: 53U,
    channels: 3U,
    colorspace: 0U 
  }

  b.bench(fn() { 
    let _ = encode(header, rgb.to_array())
  })

  b.bench(fn() { 
    let _ = decode(qoi_rgb)
  })
 
  b.bench(fn() { 
    let _ = encode(header, rgba.to_array())
  })

  b.bench(fn() { 
    let _ = decode(qoi_rgba)
  })
}
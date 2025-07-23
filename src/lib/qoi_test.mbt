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
      println("Decode failed: \{error}")
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
      println("Decode failed: \{error}")
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
      println("Decode failed: \{error}")
    }
  }
}

test "read_and_encode_image"{
  let target = @fs.read_file_to_bytes("resources/rgba_image.qoi")

  let bytes = @fs.read_file_to_bytes("resources/rgba_image.rgb")

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
      println("Decode failed: \{error}")
    }
  }
}


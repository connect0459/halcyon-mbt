///|
priv struct ScanComponent {
  component : Component
  dc_table : Huffman?
  ac_table : Huffman?
}

///|
priv struct Scan {
  components : Array[ScanComponent]
  ss : Int32
  se : Int32
  ah : Int32
  al : Int32
  progressive : Bool
  reader : BitReader
  mut eob_run : Int32
}

///|
fn required(
  table : Huffman?,
  what : String,
) -> Huffman raise @decode.DecodeError {
  match table {
    Some(t) => t
    None =>
      raise @decode.DecodeError::Malformed("missing \{what} Huffman table")
  }
}

///|
fn decode_dc_first(
  scan : Scan,
  entry : ScanComponent,
  offset : Int32,
) -> Unit raise @decode.DecodeError {
  let size = required(entry.dc_table, "DC").decode(scan.reader)
  if size > 15 {
    raise @decode.DecodeError::Malformed("invalid DC category")
  }
  let component = entry.component
  component.dc_pred += scan.reader.receive_extend(size)
  entry.component.coefficients[offset] = component.dc_pred << scan.al
}

///|
fn decode_dc_refine(
  scan : Scan,
  entry : ScanComponent,
  offset : Int32,
) -> Unit raise @decode.DecodeError {
  if scan.reader.bit() == 1 {
    entry.component.coefficients[offset] = entry.component.coefficients[offset] |
      (1 << scan.al)
  }
}

///|
fn decode_ac_first(
  scan : Scan,
  entry : ScanComponent,
  offset : Int32,
) -> Unit raise @decode.DecodeError {
  if scan.eob_run > 0 {
    scan.eob_run -= 1
    return
  }
  let table = required(entry.ac_table, "AC")
  let coefficients = entry.component.coefficients
  let mut k = scan.ss
  while k <= scan.se {
    let symbol = table.decode(scan.reader)
    let run = symbol >> 4
    let size = symbol & 15
    if size != 0 {
      k += run
      if k > 63 {
        raise @decode.DecodeError::Malformed("coefficient index out of range")
      }
      coefficients[offset + natural_order[k]] = scan.reader.receive_extend(size) <<
        scan.al
      k += 1
    } else if run == 15 {
      k += 16
    } else {
      scan.eob_run = 1 << run
      if run > 0 {
        scan.eob_run += scan.reader.bits(run)
      }
      scan.eob_run -= 1
      break
    }
  }
}

///|
fn refine_nonzero(
  scan : Scan,
  coefficients : Array[Int32],
  index : Int32,
) -> Unit raise @decode.DecodeError {
  let p1 = 1 << scan.al
  let m1 = -1 << scan.al
  if scan.reader.bit() == 1 && (coefficients[index] & p1) == 0 {
    coefficients[index] = coefficients[index] +
      (if coefficients[index] >= 0 { p1 } else { m1 })
  }
}

///|
fn decode_ac_refine(
  scan : Scan,
  entry : ScanComponent,
  offset : Int32,
) -> Unit raise @decode.DecodeError {
  let table = required(entry.ac_table, "AC")
  let coefficients = entry.component.coefficients
  let p1 = 1 << scan.al
  let m1 = -1 << scan.al
  let mut k = scan.ss
  if scan.eob_run == 0 {
    while k <= scan.se {
      let symbol = table.decode(scan.reader)
      let mut run = symbol >> 4
      let size = symbol & 15
      let mut value = 0
      if size != 0 {
        if size != 1 {
          raise @decode.DecodeError::Malformed("invalid refinement magnitude")
        }
        value = if scan.reader.bit() == 1 { p1 } else { m1 }
      } else if run != 15 {
        scan.eob_run = 1 << run
        if run > 0 {
          scan.eob_run += scan.reader.bits(run)
        }
        break
      }
      while k <= scan.se {
        let index = offset + natural_order[k]
        if coefficients[index] != 0 {
          refine_nonzero(scan, coefficients, index)
        } else {
          run -= 1
          if run < 0 {
            break
          }
        }
        k += 1
      }
      if value != 0 {
        if k > scan.se {
          raise @decode.DecodeError::Malformed("coefficient index out of range")
        }
        coefficients[offset + natural_order[k]] = value
      }
      k += 1
    }
  }
  if scan.eob_run > 0 {
    while k <= scan.se {
      let index = offset + natural_order[k]
      if coefficients[index] != 0 {
        refine_nonzero(scan, coefficients, index)
      }
      k += 1
    }
    scan.eob_run -= 1
  }
}

///|
fn decode_sequential(
  scan : Scan,
  entry : ScanComponent,
  offset : Int32,
) -> Unit raise @decode.DecodeError {
  let component = entry.component
  let coefficients = component.coefficients
  let size = required(entry.dc_table, "DC").decode(scan.reader)
  if size > 15 {
    raise @decode.DecodeError::Malformed("invalid DC category")
  }
  component.dc_pred += scan.reader.receive_extend(size)
  coefficients[offset] = component.dc_pred
  let table = required(entry.ac_table, "AC")
  let mut k = 1
  while k < 64 {
    let symbol = table.decode(scan.reader)
    let run = symbol >> 4
    let ac_size = symbol & 15
    if ac_size != 0 {
      k += run
      if k > 63 {
        raise @decode.DecodeError::Malformed("coefficient index out of range")
      }
      coefficients[offset + natural_order[k]] = scan.reader.receive_extend(
        ac_size,
      )
      k += 1
    } else if run == 15 {
      k += 16
    } else {
      break
    }
  }
}

///|
fn decode_block(
  scan : Scan,
  entry : ScanComponent,
  offset : Int32,
) -> Unit raise @decode.DecodeError {
  if !scan.progressive {
    decode_sequential(scan, entry, offset)
  } else if scan.ss == 0 {
    if scan.ah == 0 {
      decode_dc_first(scan, entry, offset)
    } else {
      decode_dc_refine(scan, entry, offset)
    }
  } else if scan.ah == 0 {
    decode_ac_first(scan, entry, offset)
  } else {
    decode_ac_refine(scan, entry, offset)
  }
}

///|
fn run_scan(
  frame : Frame,
  scan : Scan,
  restart_interval : Int32,
) -> Unit raise @decode.DecodeError {
  let interleaved = scan.components.length() > 1
  let first = scan.components[0].component
  let mcus_x = if interleaved { frame.mcus_x } else { first.scan_blocks_w }
  let mcus_y = if interleaved { frame.mcus_y } else { first.scan_blocks_h }
  for entry in scan.components {
    entry.component.dc_pred = 0
  }
  let mut restarts = 0
  for mcu in 0..<(mcus_x * mcus_y) {
    if restart_interval > 0 && mcu > 0 && mcu % restart_interval == 0 {
      scan.reader.expect_restart(restarts)
      restarts += 1
      scan.eob_run = 0
      for entry in scan.components {
        entry.component.dc_pred = 0
      }
    }
    let mx = mcu % mcus_x
    let my = mcu / mcus_x
    for entry in scan.components {
      let c = entry.component
      if interleaved {
        for v in 0..<c.v {
          for h in 0..<c.h {
            let offset = ((my * c.v + v) * c.blocks_w + mx * c.h + h) * 64
            decode_block(scan, entry, offset)
          }
        }
      } else {
        decode_block(scan, entry, (my * c.blocks_w + mx) * 64)
      }
    }
  }
  scan.reader.count = 0
}

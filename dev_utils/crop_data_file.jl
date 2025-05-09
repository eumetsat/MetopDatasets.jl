# Copyright (c) 2025 EUMETSAT
# License: MIT

using MetopDatasets
import Dates

function _get_cropped_records(file, n_data_records)
    data_class = MetopDatasets.get_record_class(MetopDatasets.DataRecord)
    dummy_group = MetopDatasets.get_instrument_group(MetopDatasets.DummyRecord)
    header_size = MetopDatasets.native_sizeof(MetopDatasets.RecordHeader)

    headers = MetopDatasets.RecordHeader[]
    records_as_byte = Vector{UInt8}[]

    data_record_count = 0
    open(file) do file_pointer
        while !eof(file_pointer) && (data_record_count < n_data_records)
            header = MetopDatasets.native_read(file_pointer, MetopDatasets.RecordHeader)

            push!(headers, header)
            skip(file_pointer, -header_size)
            byte_record = read(file_pointer, header.record_size)
            push!(records_as_byte, byte_record)

            if header.record_class == data_class && header.instrument_group != dummy_group
                data_record_count += 1
            end
        end
    end

    cropped_size = sum(length.(records_as_byte))
    @info basename(file)[1:11], n_data_records, Base.format_bytes(cropped_size)

    return data_record_count, headers, records_as_byte, cropped_size
end

function check_iprs(headers, records_as_byte, cropped_size)
    ipr_pos = [h.record_class ==
               MetopDatasets.get_record_class(MetopDatasets.InternalPointerRecord)
               for h in headers]
    iprs = [MetopDatasets.native_read(IOBuffer(elem), MetopDatasets.InternalPointerRecord)
            for elem in records_as_byte[ipr_pos]]
    if any(cropped_size < r.record_offset for r in iprs)
        error("Can not handle Internal Pointer Records referencing cropped records")
    end
    return nothing
end

function get_mphr_line(line_key, mphr_string)
    field_location = findfirst(line_key, mphr_string)
    return first(split(mphr_string[first(field_location):end], '\n'))
end

function replace_val(mphr_line, new_val)
    new_val = string(new_val)
    new_val_length = length(new_val)
    equal_location = findfirst('=', mphr_line)
    old_val_length = length(mphr_line) - equal_location
    n_space = old_val_length - new_val_length

    new_mdr_line = mphr_line[1:equal_location] * " "^n_space * new_val
    @assert length(new_mdr_line) == length(mphr_line)
    return new_mdr_line
end

mphr_get_int(mphr_line) = parse(Int, last(split(mphr_line, '=')))

function update_mphr!(mphr_bytes, last_header, cropped_size, n_data_records)
    mdr_corrections = Dict{AbstractString, AbstractString}()
    mphr_string = String(mphr_bytes[21:end])

    # update product size
    size_line = get_mphr_line("ACTUAL_PRODUCT_SIZE ", mphr_string)
    mdr_corrections[size_line] = replace_val(size_line, cropped_size)

    # update record counts 
    total_mdr_line = get_mphr_line("TOTAL_MDR ", mphr_string)
    n_dif_records = mphr_get_int(total_mdr_line) - n_data_records
    mdr_corrections[total_mdr_line] = replace_val(total_mdr_line, n_data_records)

    total_r_line = get_mphr_line("TOTAL_RECORDS ", mphr_string)
    new_total_r = mphr_get_int(total_r_line) - n_dif_records
    mdr_corrections[total_r_line] = replace_val(total_r_line, new_total_r)

    # update SENSING END
    new_stop_date = Dates.DateTime(last_header.record_stop_time)
    new_stop_date_str = Dates.format(
        new_stop_date, MetopDatasets.DATE_FORMAT_PRODUCT_HEADER) * "Z"

    sensing_end_line = get_mphr_line("SENSING_END ", mphr_string)
    mdr_corrections[sensing_end_line] = replace_val(sensing_end_line, new_stop_date_str)

    t_sensing_end_line = get_mphr_line("SENSING_END_THEORETICAL ", mphr_string)
    mdr_corrections[t_sensing_end_line] = replace_val(t_sensing_end_line, new_stop_date_str)

    # update mphr
    new_mphr = replace(mphr_string, (k => v for (k, v) in mdr_corrections)...)
    @assert length(new_mphr) == length(mphr_string)
    mphr_bytes[21:end] = Vector{UInt8}(new_mphr)
    return mphr_bytes
end

function crop_product(file, destination_folder, n_data_records)

    # get destination path
    first_part_old_name = join(split(basename(file), "_")[1:5], "_")
    new_file_name = first_part_old_name * "_cropped_$(n_data_records)" * ".nat"
    dest = joinpath(destination_folder, new_file_name)

    # read part of the product
    data_record_count, headers, records_as_byte, cropped_size = _get_cropped_records(
        file, n_data_records)

    # check assumptions
    @assert data_record_count == n_data_records
    check_iprs(headers, records_as_byte, cropped_size)

    # updata main product header
    records_as_byte[1] = update_mphr!(
        records_as_byte[1], last(headers), cropped_size, n_data_records)

    # write cropped product
    open(dest, "w") do io
        for r in records_as_byte
            write(io, r)
        end
    end

    return dest
end

full_data = raw"C:\Users\Kok\Documents\Git repos\test-data-metopdatasets\full_data"
full_files = readdir(full_data, join = true)
destination_folder = raw"C:\Users\Kok\Documents\Git repos\test-data-metopdatasets\reduced_data"
full_files

for f in full_files
    crop_product(f, destination_folder, 10)
end

crop_product(full_files[3], destination_folder, 5)
full_files[end]

Base.format_bytes(sum(filesize.(readdir(destination_folder, join = true))))

reduced_dir = raw"C:\Users\Kok\Documents\Git repos\test-data-metopdatasets\reduced_data"
out = raw"C:\Users\Kok\Documents\Git repos\test-data-metopdatasets\reduced_data"

using MetopDatasets

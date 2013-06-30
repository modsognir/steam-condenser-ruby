# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2008-2013, Sebastian Staudt

require 'core_ext/stringio'
require 'errors/timeout_error'
require 'steam/sockets/steam_socket'

# This class represents a socket used to communicate with game servers based on
# the Source engine (e.g. Team Fortress 2, Counter-Strike: Source)
#
# @author Sebastian Staudt
class SourceSocket

  include SteamSocket

  # Reads a packet from the socket
  #
  # The Source query protocol specifies a maximum packet size of 1,400 bytes.
  # Bigger packets will be split over several UDP packets. This method
  # reassembles split packets into single packet objects. Additionally Source
  # may compress big packets using bzip2. Those packets will be compressed.
  #
  # @return [SteamPacket] The packet replied from the server
  def reply
    receive_packet 1400
    is_compressed = false
    packet_checksum = 0

    if @buffer.long == 0xFFFFFFFE
      split_packets = []
      begin
        request_id = @buffer.long
        is_compressed = ((request_id & 0x80000000) != 0)
        packet_count = @buffer.getbyte
        packet_number = @buffer.getbyte + 1

        if is_compressed
          @buffer.long
          packet_checksum = @buffer.long
        else
          @buffer.short
        end

        split_packets[packet_number - 1] = @buffer.get

        puts "Received packet #{packet_number} of #{packet_count} for request ##{request_id}" if $DEBUG

        bytes_read = 0
        if split_packets.size < packet_count
          bytes_read = receive_packet rescue 0
        end
      end while bytes_read > 0 && @buffer.long == 0xFFFFFFFE

      packet = SteamPacketFactory.reassemble_packet(split_packets, is_compressed, packet_checksum)
    else
      packet = SteamPacketFactory.packet_from_data(@buffer.get)
    end

    if is_compressed
      puts "Got compressed reply of type \"#{packet.class.to_s}\"." if $DEBUG
    else
      puts "Got reply of type \"#{packet.class.to_s}\"." if $DEBUG
    end

    packet
  end

end

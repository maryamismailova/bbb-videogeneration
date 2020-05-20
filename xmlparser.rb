#!/usr/bin/ruby
require 'rexml/document'
require_relative 'videoFragments.rb'
include REXML




def getVideoFrameRate(videoPath)
    system "ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "
end
    
if ARGV.length != 1 then
    puts "arguments required"
    return
end
    
meetingId=ARGV[0]
meeting=Meeting.new(meetingId)

meetGen=MeetingGenerator.new(meeting)
objs=meetGen.readEventsFile()
puts meetGen.exposeLogs()
meetGen.generateVideos()
meetGen.mergeVideos()
# generateVideo(objects, meeting)
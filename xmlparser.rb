#!/usr/bin/ruby
require 'rexml/document'
require_relative 'videoFragments.rb'
include REXML


# SCRIPTS TO BE PLACED IN /usr/local/bigbluebutton/core/scripts/post_publish ON BBB SERVER

if ARGV.length != 1 then
    puts "arguments required"
    return
end

meetingId=ARGV[0]
meeting=Meeting.new(meetingId)

meetGen=MeetingGenerator.new(meeting)
meetGen.generatePresentationVideo()

# objs=meetGen.readEventsFile()
# puts meetGen.exposeLogs()
# meetGen.generateVideos()
# meetGen.mergeVideos()

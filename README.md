# bbb-videogeneration
A project for the video generation of the recorded meetings in Big Blue Button. 

(Theoretically, not yet tested on the server)
In order to install it:
1. Put the files inside /usr/local/bigbluebutton/core/scripts/post_publish on BBB server (directory for POST PUBLISH scripts)
2. Change the beginning of xmlparser.rb with the following code:
```
#!/usr/bin/ruby
require 'rexml/document'
require_relative 'videoFragments.rb'
include REXML
require "trollop"
require File.expand_path('../../../lib/recordandplayback', __FILE__)

opts = Trollop::options do
  opt :meeting_id, "Meeting id to archive", :type => String
end
meetingId = opts[:meeting_id]

logger = Logger.new("/var/log/bigbluebutton/post_publish.log", 'weekly' )
logger.level = Logger::INFO
BigBlueButton.logger = logger

```
3. Change the global varibale in script videoFragments.rb correspondingly:
$PATHTORAW = "/var/bigbluebutton/recording/raw" (or whichever directory contains the raw content of recording)
$PATHTOPUBLISHED="/var/bigbluebutton/published/presentation" (or whichever directory holds the published content)
$PATHTOGENERATEINTERMEDIATES= "/var/bigbluebutton/recording/raw/processing" (or any other directory name, since it will only be used for the video generation)

to start the program:
ruby xmlparser.rb [meetingId]

 - meetingId - id of the meeting to process
 

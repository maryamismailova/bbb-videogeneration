require 'fileutils'
require 'dimensions'
# gem install dimensions

$PATHTORAW="/home/maryam/Etudes/PROJECT/demo/rawdata"
$PATHTOPUBLISHED="/home/maryam/Etudes/PROJECT/demo/video/presentation"
$PATHTOGENERATEINTERMEDIATES="/home/maryam/Etudes/PROJECT/demo/rawdata/processing"

class Meeting
    @meetingId
    @start_time
    @end_time
    @participants
    @duration
    attr_accessor :meetingId
    attr_accessor :start_time
    attr_accessor :end_time
    attr_accessor :participants
    attr_accessor :duration

    def initialize(meetingId)
        @meetingId=meetingId
        pathtodeskshare="#{$PATHTOPUBLISHED}/#{meetingId}/metadata.xml"
        begin
            xmlfile = File.new(pathtodeskshare)
            xmldoc = Document.new(xmlfile)
            xmldoc.elements.each("recording"){ 
                |e|
                @start_time=e.elements["start_time"].text.to_i
                @end_time=e.elements["end_time"].text.to_i
                @participants=e.elements["participants"].text.to_i
                @duration=e.elements["playback"].elements["duration"].text.to_i
            }
        rescue => exception
            puts "Exception: "+exception.message
        end
    end

    def to_str
        return "id:#{@meetingId}, start_time:#{@start_time}, end_time:#{@end_time}, participants:#{@participants}, duration:#{@duration}"
    end
end


class VideoFragment
    @start_timestamp
    @stop_timestamp=nil
    attr_accessor :start_timestamp
    attr_accessor :stop_timestamp
    def generateVideo(destinationDir, id)

    end
end

class Slide < VideoFragment
    @presentationName
    @podId
    @slideId
    @slideNb
    attr_accessor :presentationName
    attr_accessor :podId
    attr_accessor :slideId
    attr_accessor :slideNb

    def initialize(meetingId)
        @meetingId=meetingId
    end

    def to_str
        return "slideId: #{@slideId}, slideNb:#{@slideNb}, presentationName:#{@presentationName}, timestamp:#{@start_timestamp}\n"
    end

    def construct_slide_video(duration, framerate)


    end

    def getImageSize()
        sourceDirectory="#{$PATHTOPUBLISHED}/#{@meetingId}/presentation/#{@presentationName}/slide-#{@slideNb}.png"
        width=Dimensions.width(sourceDirectory)
        height=Dimensions.height(sourceDirectory)
        return width, height
        
    end

    def generateVideo(destinationDir, id)

        name1="#{destinationDir}/ivid-#{id}.mp4"
        name="#{destinationDir}/vid-#{id}.mp4"
        puts name
        sourceDirectory="#{$PATHTOPUBLISHED}/#{@meetingId}/presentation/#{@presentationName}/slide-#{@slideNb}.png"
        width, height = getImageSize()
        width = width%2==0?width:width+1
        height = height%2==0?height:height+1
        #working but SLOW solution
        # system "ffmpeg -loop 1 -i #{sourceDirectory} -c:v libx264 -r 24 -pix_fmt yuv420p  -vf scale=#{width}:#{height} -t #{@stop_timestamp-@start_timestamp}  #{name1} -loglevel quiet"
        # system "ffmpeg -i #{name1} -vcodec vp9 #{name}"
        #attempt 2
        # system "ffmpeg -loop 1 -i #{sourceDirectory} -c:v vp9 -r 24 -pix_fmt yuv420p -t #{@stop_timestamp-@start_timestamp}  #{name} "
        #attempt 3
        system "ffmpeg -loop 1 -i #{sourceDirectory} -c:v libx264 -r 24 -pix_fmt yuv420p -vf scale=#{width}:#{height} -t #{@stop_timestamp-@start_timestamp}  #{name}  -loglevel quiet"

        puts "GENERATED #{name} \n"
    end

end

class DeskShareFragment <VideoFragment
    @id
    @@numberRead=0
    @meetingId

    def initialize(meetingId)
        @meetingId=meetingId
        @id=@@numberRead
        @@numberRead+=1
    end
    attr_accessor :id


    def generateVideo(destinationDir, id)
        name="#{destinationDir}/vid-#{id}.mp4"
        puts name
        sourceDirectory="#{$PATHTOPUBLISHED}/#{@meetingId}/deskshare/deskshare.webm"
        duration=@stop_timestamp-@start_timestamp
        # IMPOSE all videos to have same video codec - libx264
        system "ffmpeg -ss #{@start_timestamp} -i #{sourceDirectory} -c:v libx264 -c:a copy -t #{duration}  #{name} -loglevel quiet"
        puts "GENERATED #{name} \n"
    end

    def to_str
        # return "DeskShareFragment"
        return "start_timestamp: #{@start_timestamp}, stop_timestamp:#{@stop_timestamp}\n"
    end

end


class MeetingGenerator
    @logs=""
    @meetingData=nil
    @objects=nil

    def initialize(meetingData)
        @meetingData=meetingData
    end

    def writeToLogs(msg)
        @logs="#{@logs}#{msg}\n"
    end

    def exposeLogs()
        return @logs
    end
    
    def readEventsFile()
        if(@meetingData==nil)
            return 
        end
        pathtoevents="#{$PATHTORAW}/#{@meetingData.meetingId}/events.xml"
        currentDsFragment=0
        objects=Array.new
        isRecording=false
        currentSlide=nil #slide that is not recorded, but will be 
        currentDsFragment=nil #if there was any DS while non recorded state that has persisted
        startOfRecording=0
        endOfRecording=0
        recordingTimestamp=0
        recordingIntervals=Array.new
        begin
            xmlfile = File.new(pathtoevents)
            xmldoc = Document.new(xmlfile)
            xmldoc.elements.each("recording/event"){ 
                |e|
                if e.attributes["eventname"]=="RecordStatusEvent" then
                    if e.elements["status"].text == "true"
                        # puts "START Recording (#{recordingTimestamp})"
                        writeToLogs("START Recording (#{recordingTimestamp})")
                        isRecording=true
                        startOfRecording=e.elements["timestampUTC"].text.to_i
                        if currentDsFragment!=nil then
                            currentDsFragment.start_timestamp = recordingTimestamp
                            writeToLogs("RECORDING STARTS, RECORD DESKSHARE")
                            # puts "RECORDING STARTS, RECORD DESKSHARE"
                            objects.push(currentDsFragment)
                            currentDsFragment = nil
                            currentSlide=nil
                        elsif currentSlide!=nil then  
                            currentSlide.start_timestamp = recordingTimestamp
                            objects.push(currentSlide)
                            writeToLogs("RECORDING STARTS WITH LAST ADDED SLIDE")
                            # puts "RECORDING STARTS WITH LAST ADDED SLIDE"
                            currentDsFragment = nil
                            currentSlide=nil
                        end
                    else 
                        isRecording=false
                        endOfRecording=e.elements["timestampUTC"].text.to_i
                        recordingIntervals.push([startOfRecording, endOfRecording])
                        recordingTimestamp+=(endOfRecording-startOfRecording)/1000
                        # puts "STOP Recording (#{recordingTimestamp})"
                        writeToLogs("STOP Recording (#{recordingTimestamp})")
                        if(objects.length!=0)
                            objects.last().stop_timestamp=recordingTimestamp
                        end
                    end
    
                elsif e.attributes["eventname"]=="GotoSlideEvent" or e.attributes["eventname"]=="StartWebRTCDesktopShareEvent" or e.attributes["eventname"]=="StopWebRTCDesktopShareEvent" or e.attributes["eventname"]=="EndAndKickAllEvent"
                    if(isRecording==true)
                        timeFromStartOfCurrentRec=(e.elements["timestampUTC"].text.to_i - startOfRecording)/1000
                        if e.attributes["eventname"]=="StartWebRTCDesktopShareEvent"
                            dsFragment=DeskShareFragment.new(@meetingData.meetingId)
                            dsFragment.start_timestamp=timeFromStartOfCurrentRec+recordingTimestamp
                            if objects.length!=0 && objects.last().start_timestamp>=recordingTimestamp then
                                objects.last().stop_timestamp=dsFragment.start_timestamp
                            elsif objects.length!=0 && objects.last().stop_timestamp==recordingTimestamp then
                                objects.last().start_timestamp+=timeFromStartOfCurrentRec
                            end
                            objects.push(dsFragment)
                            writeToLogs("RECORD DESKSHARE #{dsFragment.start_timestamp}")
                            # puts "RECORD DESKSHARE #{dsFragment.start_timestamp}"
                        
                        elsif e.attributes["eventname"]=="StopWebRTCDesktopShareEvent"
                            if objects.length!=0 && objects.last().stop_timestamp==recordingTimestamp then
                                objects.last().stop_timestamp+=timeFromStartOfCurrentRec
                            elsif objects.length!=0
                                objects.last().stop_timestamp=timeFromStartOfCurrentRec+recordingTimestamp
                            end
                            writeToLogs("STOP RECORD DESKSHARE (#{objects.last().start_timestamp}, #{objects.last().stop_timestamp})")
                            # puts "STOP RECORD DESKSHARE (#{objects.last().start_timestamp}, #{objects.last().stop_timestamp})"
                        elsif e.attributes["eventname"]=="EndAndKickAllEvent"
                            if objects.length!=0 then
                                objects.last().stop_timestamp=timeFromStartOfCurrentRec+recordingTimestamp
                            end
                            writeToLogs("STOP ALL (#{objects.last().start_timestamp}, #{objects.last().stop_timestamp}) ")
                            # puts "STOP ALL (#{objects.last().start_timestamp}, #{objects.last().stop_timestamp}) "
                            
                        elsif e.attributes["eventname"]=="GotoSlideEvent" then
                            slide = Slide.new(@meetingData.meetingId)
                            slide.start_timestamp=timeFromStartOfCurrentRec+recordingTimestamp
                            slide.slideId=e.elements["id"].text
                            slide.slideNb=e.elements["slide"].text
                            slide.presentationName=e.elements["presentationName"].text
                            if objects.length!=0 then
                                if objects.last().start_timestamp>=recordingTimestamp then
                                    objects.last().stop_timestamp=slide.start_timestamp
                                elsif objects.last().stop_timestamp==recordingTimestamp then
                                    objects.last().stop_timestamp+=timeFromStartOfCurrentRec                            
                                end
                            end
                            objects.push(slide)
                            writeToLogs("RECORD SLIDE #{slide.start_timestamp}")
                            # puts "RECORD SLIDE #{slide.start_timestamp}"
                        end
                    else # if not recording
                        if e.attributes["eventname"]=="GotoSlideEvent" then
                            currentSlide = Slide.new(@meetingData.meetingId)
                            currentDsFragment = nil
                            currentSlide.slideId=e.elements["id"].text
                            currentSlide.slideNb=e.elements["slide"].text
                            currentSlide.presentationName=e.elements["presentationName"].text
                            writeToLogs("NON RECORDED SLIDE ")
                            # puts "NON RECORDED SLIDE "
                        elsif e.attributes["eventname"]=="StartWebRTCDesktopShareEvent" then
                            currentDsFragment = DeskShareFragment.new(@meetingData.meetingId)
                            writeToLogs("NON RECORDED DESKSHARE STARTED ")
                            # puts "NON RECORDED DESKSHARE STARTED "
                        elsif e.attributes["eventname"]=="StopWebRTCDesktopShareEvent"
                            currentDsFragment = nil
                            writeToLogs("NON RECORDED DESKSHARE STOPPED")
                            # puts "NON RECORDED DESKSHARE STOPPED"
                        end
    
                    end
                end   
            }
        rescue => exception
            puts "Exception: #{exception.message}"
        end
        @objects=objects
        return objects
    end

    def generateVideos()
        #GENERATE AN INTERMEDIARY DIRECTORY WHERE WE'D STORE THE VIDEO FRAGMENTS
        pathToIntermediates="#{$PATHTOGENERATEINTERMEDIATES}/#{@meetingData.meetingId}"
        puts "generating intermediate videos in #{pathToIntermediates}"
        if Dir.exist?pathToIntermediates
            puts "directory exists!"
           FileUtils.remove_dir(pathToIntermediates) 
           puts "removed old one"
           FileUtils.mkdir_p pathToIntermediates
            puts "created a new one"
        else
            puts "directory doesnt exist"
            FileUtils.mkdir_p pathToIntermediates
            puts "created a new one"
        end
    
        #TODO . CHECK IF THE EXTENSION of video IS CORRECT!!!!
        dsPath="#{$PATHTOPUBLISHED}/#{@meetingData.meetingId}/deskshare/deskshare.webm"
        presentationPath="#{$PATHTOPUBLISHED}/#{@meetingData.meetingId}/presentation"
        @objects.each_with_index{
            |val, index|
            if val.instance_of?DeskShareFragment then
                #puts "Generating a video from #{dsPath} in interval [#{val.start_timestamp}, #{val.stop_timestamp}]"
                #here function to generate that video
            elsif val.instance_of?Slide then
                #TODO  NOT SURE ABOUT STOP TIMESTAMP
                # val.stop_timestamp=(index==videoFragmentArray.length-1)?meetingData.end_time : videoFragmentArray[index+1].start_timestamp
                # puts "Generating slide video from #{presentationPath}/#{val.presentationName}/slide-#{val.slideNb}.png  in interval [#{val.start_timestamp}, #{val.stop_timestamp}]"
                #here function to generate that vide
            end
            puts "Generating a #{val.class} video in interval [#{val.start_timestamp}, #{val.stop_timestamp}]"
            val.generateVideo(pathToIntermediates, index)
        }
    
    end
    def mergeVideos()
        pathToIntermediates="#{$PATHTOGENERATEINTERMEDIATES}/#{@meetingData.meetingId}"
        vidList="#{pathToIntermediates}/vidList.txt"
        system "echo >#{vidList}"
        (0...@objects.length).each do |e|
            system "echo file \'#{pathToIntermediates}/vid-#{e}.mp4\' >> #{vidList}"    
        end
        # system "echo \"file \'#{pathToIntermediates}/vid-#{@objects.length-1}.mp4\'\" >> #{vidList}" 
        puts "vidList generated"

        system "ffmpeg -f concat -safe 0 -i #{vidList} -c copy #{pathToIntermediates}/output.mp4 "
    end
end




# def readEventsFile(meetingData)
#     pathtoevents="#{$PATHTORAW}/#{meetingData.meetingId}/events.xml"
#     # puts pathtoevents
#     # dsFragments=DeskShareFragment.readDeskShareXml(meetingData.meetingId)
#     currentDsFragment=0
#     objects=Array.new
#     begin
#         xmlfile = File.new(pathtoevents)
#         xmldoc = Document.new(xmlfile)
#         xmldoc.elements.each("recording/event"){ 
#             |e|
#             if e.attributes["eventname"]=="GotoSlideEvent" or e.attributes["eventname"]=="StartWebRTCDesktopShareEvent" or e.attributes["eventname"]=="StopWebRTCDesktopShareEvent" 
                
#                 if e.attributes["eventname"]=="StartWebRTCDesktopShareEvent"
#                     dsFragment=DeskShareFragment.new
#                     dsFragment.start_timestamp=e.elements["timestampUTC"].text.to_i-meetingData.start_time
#                     objects.push(dsFragment)
                
#                 elsif e.attributes["eventname"]=="StopWebRTCDesktopShareEvent"
#                     dsFragment=objects.last()
#                     dsFragment.stop_timestamp=e.elements["timestampUTC"].text.to_i-meetingData.start_time

#                 elsif e.attributes["eventname"]=="GotoSlideEvent" then
#                         slide =Slide.new
#                         slide.start_timestamp=e.elements["timestampUTC"].text.to_i-meetingData.start_time
#                         slide.slideId=e.elements["id"].text
#                         slide.slideNb=e.elements["slide"].text
#                         slide.presentationName=e.elements["presentationName"].text
#                         objects.push(slide)
#                 end
#             end   
#         }
#     rescue => exception
#         puts "Exception: #{exception.message}"
#     end
#     return objects
# end

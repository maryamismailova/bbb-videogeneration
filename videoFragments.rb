require 'fileutils'
require 'dimensions'
# gem install dimensions





# commands:
# TO RESIZE WITH PADDING:
# ffmpeg -i vid-2.mp4 -vf "scale=iw*min(1280/iw\,700/ih):ih*min(1280/iw\,700/ih), pad=1280:700:(1280-iw*min(1280/iw\,700/ih))/2:(700-ih*min(1280/iw\,700/ih))/2" vid2resized.mp4

# TO OVERLAY VIDEOS:
# ffmpeg -i vid0resized.mp4 -i webresized.webm -filter_complex 'overlay=x=main_w-overlay_w-10:y=main_h-overlay_h-10'  combined.mp4

# TO GET VIDEO RESOLUTION:
# ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 output.mp4

# TO RESIZE A VIDE
# ffmpeg -i inputvideo -vf scale=200:-1  output.mp4
# ffmpeg -i webcams.webm -vcodec libx264 -vf scale=200:-1 resized.mp4


#Directory of all recorded sources - /var/bigbluebutton/recording/raw
$PATHTORAW="/home/maryam/Etudes/PROJECT/demo/rawdata"
# Directory of all published presentations - /var/bigbluebutton/published/presentation
$PATHTOPUBLISHED="/home/maryam/Etudes/PROJECT/demo/video/presentation"
# An intermediate directory, to be automatically created for each processing - anydirectory
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
    def generateVideo(destinationDir, id, maxW=0, maxH=0)

    end

    def getResolution()
        return 0,0
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

    def getImageSize()
        sourceDirectory="#{$PATHTOPUBLISHED}/#{@meetingId}/presentation/#{@presentationName}/slide-#{@slideNb}.png"
        width=Dimensions.width(sourceDirectory)
        height=Dimensions.height(sourceDirectory)
        return width, height
        
    end

    def generateVideo(destinationDir, id, maxW=0, maxH=0)


        name1="#{destinationDir}/ivid-#{id}.mp4"
        name="#{destinationDir}/vid-#{id}.mp4"
        puts name
        sourceDirectory="#{$PATHTOPUBLISHED}/#{@meetingId}/presentation/#{@presentationName}/slide-#{@slideNb}.png"
        width, height = getImageSize()
        width = width%2==0?width:width+1
        height = height%2==0?height:height+1
        # attempt 4 with rescaling
        if maxH!=0 or maxW!=0 then
            system "ffmpeg -loop 1 -i #{sourceDirectory} -c:v libx264 -r 24 -pix_fmt yuv420p -vf \"scale=iw*min(#{maxW}/iw\\,#{maxH}/ih):ih*min(#{maxW}/iw\\,#{maxH}/ih), pad=#{maxW}:#{maxH}:(#{maxW}-iw*min(#{maxW}/iw\\,#{maxH}/ih))/2:(#{maxH}-ih*min(#{maxW}/iw\\,#{maxH}/ih))/2 \" -t #{@stop_timestamp-@start_timestamp}  #{name} -loglevel quiet"
        else
            system "ffmpeg -loop 1 -i #{sourceDirectory} -c:v libx264 -r 24 -pix_fmt yuv420p -vf scale=#{width}:#{height} -t #{@stop_timestamp-@start_timestamp}  #{name}  -loglevel quiet"
        end    
        puts "GENERATED #{name} \n"
    end

    def getResolution()
        vid="#{$PATHTOPUBLISHED}/#{@meetingId}/presentation/#{@presentationName}/slide-#{@slideNb}.png"
        wh=`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 #{vid}`
        wh=wh.split(',')
        return wh[0].to_i, wh[1].to_i
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


    def generateVideo(destinationDir, id, maxW=0, maxH=0)
        name="#{destinationDir}/vid-#{id}.mp4"
        puts name
        sourceDirectory="#{$PATHTOPUBLISHED}/#{@meetingId}/deskshare/deskshare.webm"
        duration=@stop_timestamp-@start_timestamp
        # IMPOSE all videos to have same video codec - libx264
        system "ffmpeg -ss #{@start_timestamp} -i #{sourceDirectory} -c:v libx264 -c:a copy -t #{duration}  #{name} -loglevel quiet"
        puts "GENERATED #{name} \n"
    end

    def to_str
        return "start_timestamp: #{@start_timestamp}, stop_timestamp:#{@stop_timestamp}\n"
    end

    def getResolution()
        vid="#{$PATHTOPUBLISHED}/#{@meetingId}/deskshare/deskshare.webm"
        wh=`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 #{vid}`
        wh=wh.split(',')
        return wh[0].to_i, wh[1].to_i
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

    # TO IMPROVE
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
                        writeToLogs("START Recording (#{recordingTimestamp})")
                        isRecording=true
                        startOfRecording=e.elements["timestampUTC"].text.to_i
                        # CHECK if any element was changed when recording was off
                        if currentDsFragment!=nil then
                            currentDsFragment.start_timestamp = recordingTimestamp
                            writeToLogs("RECORDING STARTS, RECORD DESKSHARE")
                            objects.push(currentDsFragment)
                        elsif currentSlide!=nil then  
                            currentSlide.start_timestamp = recordingTimestamp
                            objects.push(currentSlide)
                            writeToLogs("RECORDING STARTS WITH LAST ADDED SLIDE")
                            # RESET the elements to null
                            currentDsFragment = nil
                            currentSlide=nil
                        end
                        currentDsFragment = nil
                        currentSlide=nil
                    else 
                        isRecording=false
                        endOfRecording=e.elements["timestampUTC"].text.to_i
                        recordingIntervals.push([startOfRecording, endOfRecording])
                        recordingTimestamp+=(endOfRecording-startOfRecording)/1000

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
                                objects.last().stop_timestamp+=timeFromStartOfCurrentRec
                            end
                            objects.push(dsFragment)
                            writeToLogs("RECORD DESKSHARE #{dsFragment.start_timestamp}")
                        
                        elsif e.attributes["eventname"]=="StopWebRTCDesktopShareEvent"
                            if objects.length!=0 && objects.last().stop_timestamp==recordingTimestamp then
                                objects.last().stop_timestamp+=timeFromStartOfCurrentRec
                            elsif objects.length!=0
                                objects.last().stop_timestamp=timeFromStartOfCurrentRec+recordingTimestamp
                            end
                            writeToLogs("STOP RECORD DESKSHARE (#{objects.last().start_timestamp}, #{objects.last().stop_timestamp})")

                        elsif e.attributes["eventname"]=="EndAndKickAllEvent"
                            if objects.length!=0 then
                                objects.last().stop_timestamp=timeFromStartOfCurrentRec+recordingTimestamp
                            end
                            writeToLogs("STOP ALL (#{objects.last().start_timestamp}, #{objects.last().stop_timestamp}) ")

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

                        end
                    else # if not recording
                        if e.attributes["eventname"]=="GotoSlideEvent" then
                            currentSlide = Slide.new(@meetingData.meetingId)
                            currentDsFragment = nil
                            currentSlide.slideId=e.elements["id"].text
                            currentSlide.slideNb=e.elements["slide"].text
                            currentSlide.presentationName=e.elements["presentationName"].text
                            writeToLogs("NON RECORDED SLIDE ")

                        elsif e.attributes["eventname"]=="StartWebRTCDesktopShareEvent" then
                            currentDsFragment = DeskShareFragment.new(@meetingData.meetingId)
                            writeToLogs("NON RECORDED DESKSHARE STARTED ")

                        elsif e.attributes["eventname"]=="StopWebRTCDesktopShareEvent"
                            currentDsFragment = nil
                            writeToLogs("NON RECORDED DESKSHARE STOPPED")

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

    # METHOD to create a list of video fragments according to timeline
    def generateVideos()
        #GENERATE AN INTERMEDIARY DIRECTORY WHERE WE'D STORE THE VIDEO FRAGMENTS
        pathToIntermediates="#{$PATHTOGENERATEINTERMEDIATES}/#{@meetingData.meetingId}"
        puts "generating intermediate videos in #{pathToIntermediates}"
        if Dir.exist?pathToIntermediates
            # remove old one and create a new directory
           FileUtils.remove_dir(pathToIntermediates) 
           FileUtils.mkdir_p pathToIntermediates
        else
            # create a directory
            FileUtils.mkdir_p pathToIntermediates
        end
    
        dsPath="#{$PATHTOPUBLISHED}/#{@meetingData.meetingId}/deskshare"
        presentationPath="#{$PATHTOPUBLISHED}/#{@meetingData.meetingId}/presentation"
        
        #Scale to optimal resolution
        maxW=0
        maxH=0
        if Dir.exist?dsPath then
            maxW, maxH = getMaxResolution(dsPath)
        else  
            maxW, maxH = getMaxResolution()
        end


        @objects.each_with_index{
            |val, index|
            puts "Generating a #{val.class} video in interval [#{val.start_timestamp}, #{val.stop_timestamp}]"
            val.generateVideo(pathToIntermediates, index, maxW, maxH)
        }   
    end

    # METHOD to merge all the separate video fragments for presentation+deskshare
    def mergeVideos()
        pathToIntermediates="#{$PATHTOGENERATEINTERMEDIATES}/#{@meetingData.meetingId}"
        vidList="#{pathToIntermediates}/vidList.txt"
        # Create a txt file with the lists of all videos to concatenate
        system "echo >#{vidList}"
        (0...@objects.length).each do |e|
            system "echo file \'#{pathToIntermediates}/vid-#{e}.mp4\' >> #{vidList}"    
        end
        # Concatenate videos from the txt file
        system "ffmpeg -f concat -safe 0 -i #{vidList} -c copy #{pathToIntermediates}/output.mp4 "
    end

    # METHOD to add webcam recording to final video
    def addWebCam()
        pathToWebcam  = "#{$PATHTOPUBLISHED}/#{@meetingData.meetingId}/video/webcams.webm"
        pathToIntermediates= "#{$PATHTOGENERATEINTERMEDIATES}/#{@meetingData.meetingId}"

        # resize the webcam video
        system "ffmpeg -i #{pathToWebcam}  -vcodec libx264 -vf scale=200:-1  #{pathToIntermediates}/webcamResized.mp4"
        #merge it with the presentation+deskshare video
        system "ffmpeg -i #{pathToIntermediates}/output.mp4 -i #{pathToIntermediates}/webcamResized.mp4 -filter_complex \' overlay=x=main_w-overlay_w-10:y=main_h-overlay_h-10 \' #{pathToIntermediates}/finalcut.mp4"
    end

    def generatePresentationVideo()
        readEventsFile()
        puts "Video timeline reconstruction completed"
        generateVideos()
        puts "Video fragments generation completed"
        mergeVideos()
        puts "Merge of videos completed"
        addWebCam()
        puts "WebCam video has been concatenated"
    end

    def getMaxResolution(dsPath=nil)

        if(dsPath==nil) then
            maxW=0
            maxH=0
            @objects.each{
                |video|
                curW, curH = video.getResolution()
                if curW > maxW then
                    maxW = curW
                    maxH = curH
                elsif curW==maxW then
                    if curH > maxH then
                        maxH=curH
                    end
                end
            }
            return maxW, maxH
        else
            vid="#{dsPath}/deskshare.webm"
            wh=`ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 #{vid}`
            wh=wh.split(',')
            return wh[0].to_i, wh[1].to_i
        end
    end

    def printTimeline()
        @objects.each_with_index{
            |val, index|
            puts "#{val.class} video in interval [#{val.start_timestamp}, #{val.stop_timestamp}]"
        }  
    end

end

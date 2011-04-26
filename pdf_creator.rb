require "rubygems"
require 'mq'
require 'json'

Signal.trap('INT') { AMQP.stop{ EM.stop } }
Signal.trap('TERM'){ AMQP.stop{ EM.stop } }

puts "Welcome"
puts "Starting PDF-creator..."

def create_new_file(recieved_message, request)
    locale_fop_path = "/home/sfate/prj/last_odt/vendor/fop-1.0"
    #locale_fop_path = "/home/last_odt/vendor/fop-1.0"
    p "> > > recieved_message #{recieved_message.inspect}"
    p "> > > request #{request}"
    p "recieved_message['src'] = #{recieved_message['src']}"
    name_of_fo = recieved_message["src"].scan(/\w+\.\w+$/).to_s.split('.')[0]
    p ">>> name_of_fo #{name_of_fo}"
    fo_receive= name_of_fo

    sleep 2
    #send message to broker
    puts "data is sended"

    complete_pdf_path = "#{recieved_message["src"].gsub(/\w+\.\w+$/,"").gsub("tmp/fo/","")}public/files/completed_pdf/#{name_of_fo}.pdf"

    # We generate the classpath by scanning the FOP lib directory
    command = "java -cp #{locale_fop_path}/build/fop.jar"
    Dir.foreach("#{locale_fop_path}/lib") do |file|
      command << ":#{locale_fop_path }/lib/#{file}" if (file.match(/.jar/))
    end
    command << " org.apache.fop.cli.Main "
    command << " -fo #{recieved_message['src']}"
 #   command << " -xsl #{locale_fop_path}/xslt/doc2fo.xsl"
    command << " -pdf #{complete_pdf_path}"
    puts "command is #{command}"
    if(Kernel.system command) then
      puts "Yahoo, it's done!'"
    else
      puts "creating pdf fail :'("
    end

    data_to_send = {
  	  :pdf_url => "#{complete_pdf_path}",
    }.to_json

    request.publish(data_to_send)
end

recieved_message = ""
AMQP.start(:host => 'sloboda-studio.com', :port => '5672') do

  if_mesage_is_not_nil = false
  MQ.queue('create_send').subscribe(:ack => true) do |h,m|
      puts m
      unless m.nil?
        recieved_message = JSON.parse(m)
        h.ack
        puts recieved_message.inspect
        if_mesage_is_not_nil = true
      end
      if if_mesage_is_not_nil
        puts "check nil message or not"
        if_mesage_is_not_nil = false
        create_new_file(recieved_message, MQ.queue('create_respond'))
      end
  end
  recieved_message
end


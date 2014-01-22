#!/usr/local/bin/ruby

################################################################################
# The MIT License (MIT)
#
# Copyright (c) 2014 ContactUs, LLC & Ray Bohac
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################


require 'sinatra'
require 'rubygems'
require 'mysql'
require 'json'
require 'yaml'

set :bind, '0.0.0.0'
set :protection, :except => [:json_csrf]  #diables setting to allow cross site queries

get '/' do
  "Instructions:<br>
	<a href='/test/'>/test/</a> - a test page<br>
	<a href='/getstatus/'>getstatus</a> - an html page of all statuses<br>
	/getstatusjson/ - an json array of all statuses formatted for jquery datatables<br>
	/getstatusjsonp/ - an jsonp array of all statuses formatted for jquery datatables<br>
	<a href='/setstatus/?appname=instructions_test&status=G&status_text=&customer=test&category=test&description=Is%20the%20tripwire%20system%20running%20and%20responding&expires=86400'>/setstatus/</a> - sets the status if a tigger. Requires params appname & status. Optional: status_text,description,expires,category,customer<br>
	<a href='/removestatus/?appname=instructions_test'>/removestatus/</a> - Removes a status form the system <i>(Note: Is another system sends a setstatus message, the monitor will be recreated automatically</i><br>
	<a href='/suspendstatus/?appname=instructions_test'>/suspendstatus/</a> - Stops monitor for a period of time<br>
"
end



get '/setstatus/' do
  halt raiseParameterMissing("appname") if params[:appname].nil?
  halt raiseParameterMissing("status") if params[:status].nil?
  halt raiseBadStatusValue() unless ["R","Y","G","I","S"].include?(params[:status])

  setstatus_base
end


get '/suspendstatus/' do
  halt raiseParameterMissing("appname") if params[:appname].nil?

  expires=mysql_escape(params[:expires])
  params[:status_text] = "Alarm Turned Off"
  params[:status] = "S"

  if expires.nil? || expires.empty?
      expires="86400"
  end

  setstatus_base
end


def setstatus_base
  db=setup_db

  appname=mysql_escape(params[:appname])
  expires=mysql_escape(params[:expires])
  status=mysql_escape(params[:status])
  status_text=mysql_escape(params[:status_text])
  description=mysql_escape(params[:description])
  category=mysql_escape(params[:category])
  customer=mysql_escape(params[:customer])

  if expires.nil? || expires.empty?
      expires="86400"
  end

  expires_sql = "DATE_ADD(now() , INTERVAL #{expires} SECOND)"



  #Is the monitor suspended? If so, do not override the suspension
  sql = "select id,status,status_text,TIMESTAMPDIFF(SECOND,lastupdated,now()) from monitors where id='#{appname}' and expires > now()"
  results=db.query(sql)
  results.each do |row|
    if (row[1] == "S")
   	status_text = "Monitor Turned Off. Last update suppressed Status=#{status} Text=#{status_text}"	
      	status="S"
	expires_sql="expires" #don't update expires field. Set it to itself in SQL
    end
  end
   
 
  #Create SQL Query for main monitor table  
  sql = "
	insert into monitors (id,lastupdated,expires,status,status_text,description,category,customer) values(
	      	'#{appname}',
  	      	NOW(),
    	      	#{expires_sql},
	      	'#{status}',
	      	'#{status_text}',
	      	'#{description}',
	      	'#{category}',
	      	'#{customer}'
    	)
    	ON DUPLICATE KEY UPDATE
      		lastupdated=now(),
      		expires=#{expires_sql},
      		status='#{status}',
     		status_text='#{status_text}'"

    sql << ",description='#{description}'" unless (description.nil? || description.empty?)
    sql << ",category='#{category}'" unless (category.nil? || category.empty?)
    sql << ",customer='#{customer}'" unless (customer.nil? || customer.empty?)


  #Create SQL Query for historical monitor_history table
  sql_history = "
	    insert into monitors_history 
	    (ident,monitor_id,lastupdated,expires,status,status_text,description,category,customer) values(null,
	      	'#{appname}',
        	NOW(),
    	  	DATE_ADD(now() , INTERVAL #{expires} SECOND),
	      	'#{status}',
	      	'#{status_text}',
	      	'#{description}',
	      	'#{category}',
	      	'#{customer}')"

  db.query(sql);
  db.query(sql_history);
  content_type :json
  params.to_json
end

get '/removestatus/' do
  db=setup_db
  halt raiseParameterMissing("appname") if params[:appname].nil?

  appname=mysql_escape(params[:appname])
  
  sql = "delete from monitors where id ='#{appname}'";

  db.query(sql);
  content_type :json
  params.to_json
end


get '/getstatusjson/' do
  output = getStatus_Base
  content_type :json
  "#{output.to_json}"
end

get '/getstatusjsonp/' do
  output = getStatus_Base
  content_type :json
  headers['Access-Control-Allow-Origin'] = "*"
  headers['Access-Control-Allow-Methods'] = "GET, POST, PUT, DELETE, OPTIONS"
  headers['Access-Control-Allow-Headers'] ="accept, authorization, origin"
  callback=params[:callback]
  "#{callback}(#{output.to_json})"
end

def getStatus_Base
   db=setup_db
  sql = "select id,lastupdated,expires,description,category,customer,status,status_text,TIMESTAMPDIFF(SECOND,expires,now()) as expires_diff, TIMESTAMPDIFF(SECOND,lastupdated,now()) as lastupdated_diff from monitors order by id"
  results=db.query(sql)
  aaData=[]
  results.each do |row|
    row[2] = gettimedifference(row[8].to_i); # expires_diff
    row[1] = gettimedifference(row[9].to_i); # lastupdated_diff
    aaData << row
  end

  begin
    sEcho=params[:sEcho]
  rescue
    sEcho=0
  end;
  output = {    "sEcho" => sEcho,
                #"iTotalRecords" =>  count.to_s,
                "iTotalRecords" =>  aaData.count.to_s,
                "aaData" => aaData }

end


get '/gethistoryjson/' do
  halt raiseParameterMissing("appname") if params[:appname].nil?
  output = getHistory_Base
  content_type :json
  "#{output.to_json}"
end

get '/gethistoryjsonp/' do
  halt raiseParameterMissing("appname") if params[:appname].nil?
  output = getHistory_Base
  content_type :json
  callback=params[:callback]
  "#{callback}(#{output.to_json})"
end


def getHistory_Base
   db=setup_db
	monitor_id = params[:appname]
  sql = "select monitor_id,lastupdated,expires,description,category,customer,status,status_text,
		TIMESTAMPDIFF(SECOND,expires,now()) as expires_diff, TIMESTAMPDIFF(SECOND,lastupdated,now()) as lastupdated_diff 
		from monitors_history 
		where monitor_id ='#{monitor_id}'
		order by ident desc
"

  puts sql

  results=db.query(sql)
  aaData=[]
  results.each do |row|
    row[2] = gettimedifference(row[8].to_i); # expires_diff
    row[1] = gettimedifference(row[9].to_i); # lastupdated_diff
    aaData << row
  end

  begin
    sEcho=params[:sEcho]
  rescue
    sEcho=0
  end;
  output = {    "sEcho" => sEcho,
                #"iTotalRecords" =>  count.to_s,
                "iTotalRecords" =>  aaData.count.to_s,
                "aaData" => aaData }

end




get '/getsummaryjson/' do
  result = Hash.new
  result['R']="0"
  result['Y']="0"
  result['G']="0"
  result['I']="0"

  sql = "select status, count(*) from monitors group by status" 
  db=setup_db
  results=db.query(sql)
  results.each do |row|
    result[row[0]] = row[1].to_s
  end

  content_type:json
    headers['Access-Control-Allow-Origin'] = "*"
    headers['Access-Control-Allow-Methods'] = "GET, POST, PUT, DELETE, OPTIONS"
    headers['Access-Control-Allow-Headers'] ="accept, authorization, origin"
  result.to_json
end



get '/getstatus/' do
  db=setup_db
  sql = "select id,lastupdated,expires,description,category,customer,status,status_text from monitors order by id"
  results=db.query(sql)

  output="<table border='1'>
	       <tr>
		<td>Name</td>
		<td>LastUpdated</td>
		<td>Expires</td>
		<td>Description</td>
		<td>Category</td>
		<td>Customer</td>
		<td>Status</td>
		<td>Status Text</td>
	      </tr>
         "
  results.each do |row|
    status_color=rowcolor(row[6])
    output << "<tr bgcolor='#{status_color}'>
		<td>#{row[0]}</td>
		<td>#{row[1]}</td>
		<td>#{row[2]}</td>
		<td>#{row[3]}</td>
		<td>#{row[4]}</td>
		<td>#{row[5]}</td>
		<td>#{row[6]}</td>
		<td>#{row[7]}</td>
  	       </tr>"
  end
  output << "</table>"
  output
end



def stringOrBlank(value)
  begin
    value
  rescue
    String.new
  end
end

def raise400Error(body_text)
  status 400
  body body_text
end

def raiseParameterMissing(param_name)
  raise400Error("A required parameter is missing in your request: #{param_name}")
end

def raiseBadStatusValue
  raise400Error("Status value must be one of R,Y,G, or I")
end










#################################################
# Testing interface for development. Simply call http://<server>:4567/test/

get '/test/' do

  output ="

	<html><head></head><body>
	<form action='/setstatus/' target='result_frame'>
	<table>
	<tr><td>appname:</td><td> <input name='appname'> </td></tr>
	<tr><td>status:</td><td> <select name='status'>
		<option value='R'> Red
		<option value='Y'> Yellow
		<option value='G'> Green
	</select></td></tr>
	<tr><td>status text:</td><td> <input name='status_text'> </td></tr>
	<tr><td>expires:</td><td> <select name='expires'>
		<option value='60'> 1 minute
		<option value='300'> 5 minute
		<option value='3600'> 1 hour 
		<option value='86400'> 1 day 
	</select></td></tr>
	<tr><td>description:</td><td> <input name='description'></td></tr>
	<tr><td>category:</td><td> <input name='category'></td></tr>
	<tr><td>customer:</td><td> <input name='customer'></td></tr>
	</table>

	<input type='submit'>
	</form>
	<hr><hr> 
	<iframe width='100%' height='50%' name='result_frame'></iframe>
	</body></html>
	"
  output
end


def setup_db
  #http://blog.aizatto.com/2007/05/21/activerecord-without-rails/
  dbconfig = YAML::load(File.open('database.yml'))["development"]
  puts dbconfig.inspect
  Mysql.new(dbconfig["host"],dbconfig["username"],dbconfig["password"],dbconfig["database"])
end

def rowcolor(row_status)
  case row_status
    when "R"
      status_color="#FF9999"
    when "Y"
      status_color="#FFFFD1"
    when "G"
      status_color="#C2F0C2"
    else
      status_color="#D6D6D6"
    end
end

def mysql_escape(s)
  s = stringOrBlank(s) # ignore nil and return blank string
  if s.nil?
    String.new
  else
    s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
  end
end

def gettimedifference(seconds)
  a = seconds
  suffix = " ago"
  prefix = ""
  if (seconds < 0)
    suffix = ""
    prefix = "In "
    seconds = seconds * -1
  end

  days = seconds / (24*60*60)
  seconds = seconds - (days * 24*60*60)

  hours = seconds / (60*60)
  seconds = seconds - (hours * 60*60)

  minutes = seconds / (60)
  seconds = seconds - (minutes * 60)

  resddult = "(" << a.to_s << ") " << prefix << days.to_s << "D " <<hours.to_s << "H " << minutes.to_s << "M " << seconds.to_s << "S" << suffix


  result = prefix
  if (days > 0)
    result << days.to_s << "D "
  end

  if ((days > 0) || (hours > 0))
    result <<hours.to_s << "H "
  end

  if ((days > 0) || (hours > 0) || (minutes > 0))
    result << minutes.to_s << "M "
  end
  result <<  seconds.to_s << "S" << suffix

  result
end

# Fix "net/http certificate verify failed" error
# Per: https://gist.github.com/fnichol/867550
# - Download the cacert.pem file from http://curl.haxx.se/ca/cacert.pem.
# - Save this file to C:\RailsInstaller\cacert.pem.
# - Now make ruby aware of your certificate authority bundle by setting SSL_CERT_FILE.
# - To set this in your current command prompt session, type:
#     set SSL_CERT_FILE=C:\RailsInstaller\cacert.pem
# - To make this a permanent setting, add this in your control panel.

# Ultimately added this as an Environment Variable in Windows:
# - Control Panel\All Control Panel Items\System screen > Advanced system settings link
# - Advanced tab > Environment Variables button
# - Environment Variables screen > New...
#   - Variable name:  SSL_CERT_FILE
#   - Variable Value: C:\<path to downloaded cacert.pem>\cacert.pem
# - OK > OK > OK
# - close & re-open termainal and app will work locally on Windows

require 'json'
require 'net/http'
require 'digest/sha1'
require 'pp'
# require 'mysql2'  # used by query_b2()

load "./local_env.rb" if File.exists?("./local_env.rb")

# define connection parameters (GearHost MySQL)
# db_params = {
#     host: ENV['host'],
#     port: ENV['port'],
#     username: ENV['username'],
#     password: ENV['password'],
#     database: ENV['database']
# }

# client = Mysql2::Client.new(db_params)  # connect to the database

# ------------------------- DB records setup ---------------------------------

# # drop testing table if it exists
# client.query("drop table if exists testing")

# # create the testing table
# client.query(
#     "create table portfoliojv.testing (
#         id smallint not null auto_increment,
#         photo varchar(50) null,
#         constraint PK_species primary key (id)
#     )"
# ) 

# client.query("insert into testing (photo) values ('redfish.png')")
# client.query("insert into testing (photo) values ('bluefish.png')")
# client.query("insert into testing (photo) values ('oldfish.png')")
# client.query("insert into testing (photo) values ('newfish.png')")

# ----------------------------------------------------------------------------

# Returns Ruby hash for input JSON (string)
def convert_json(json)

    return JSON.parse(json)

end

# Commands:
# file_json = '{"fileId": "4_z84c14bea3e43f5c56c21061e_d20180419_m002318_c002_v0001094_t0044",
#              "fileName": "nemo.png"}'
# pp convert_json(file_json)
#
# Returns:
# {
#     "fileId"=>"4_z84c14bea3e43f5c56c21061e_d20180419_m002318_c002_v0001094_t0044",
#     "fileName"=>"nemo.png"
# }


# Returns autorization session info
# - use http.verify_mode to be able to run via localhost and get past this error:
#   SSL_connect returned=1 errno=0 state=error: certificate verify failed (unable to get local issuer certificate) (OpenSSL::SSL::SSLError)
# - see: https://mislav.net/2013/07/ruby-openssl/
# - works, but fails on file upload - going back to local pem file (see notes at top)
def b2_authorize_account()

    account_id = ENV['account_id']
    application_key = ENV['application_key']

    uri = URI("https://api.backblazeb2.com/b2api/v1/b2_authorize_account")
    req = Net::HTTP::Get.new(uri)	
    req.basic_auth(account_id, application_key)    
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    # http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # only for localhost testing, remove for production
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
puts b2_authorize_account()
#
# Returns:
# {
#   "absoluteMinimumPartSize": 5000000,
#   "accountId": "41b5243de1ae",
#   "apiUrl": "https://api002.backblazeb2.com",
#   "authorizationToken": "3_201865e2fd1700_4501015f0bca9c3ea234fea27c482080707a780e_002_acct",
#   "downloadUrl": "https://f002.backblazeb2.com",
#   "minimumPartSize": 100000000,
#   "recommendedPartSize": 100000000
# }


# 
def b2_list_buckets()

    auth_hash = convert_json(b2_authorize_account)
    api_url = auth_hash["apiUrl"] # Provided by b2_authorize_account
    account_id = auth_hash["accountId"] # Obtained from your B2 account page
    account_authorization_token = auth_hash["authorizationToken"] # Provided by b2_authorize_account

    uri = URI("#{api_url}/b2api/v1/b2_list_buckets")
    req = Net::HTTP::Post.new(uri)
    req.add_field("Authorization","#{account_authorization_token}")
    req.body = "{\"accountId\":\"#{account_id}\"}"
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
# puts b2_list_buckets()
#
# Returns:
# {
#   "buckets": [
#     {
#       "accountId": "41b5243de1ae",
#       "bucketId": "84c14bea3e43f5c56c21061e",
#       "bucketInfo": {},
#       "bucketName": "portfolio-jv",
#       "bucketType": "allPublic",
#       "corsRules": [],
#       "lifecycleRules": [],
#       "revision": 2
#     }
#   ]
# }


# List all files in bucket
def b2_list_file_names_original()

    auth_hash = convert_json(b2_authorize_account)
    api_url = auth_hash["apiUrl"]
    account_authorization_token = auth_hash["authorizationToken"]
    bucket_id = ENV['bucket_id']

    uri = URI("#{api_url}/b2api/v1/b2_list_file_names")
    req = Net::HTTP::Post.new(uri)
    req.add_field("Authorization","#{account_authorization_token}")
    req.body = "{\"bucketId\":\"#{bucket_id}\"}"
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
# puts b2_list_file_names_original()
#
# Returns:
# {
#   "files": [
#     {
#       "action": "upload",
#       "contentLength": 91619,
#       "contentSha1": "8920277296d22005976a34cd8ed01526ac51d13e",
#       "contentType": "image/png",
#       "fileId": "4_z84c14bea3e43f5c56c21061e_d20180415_m172715_c002_v0001095_t0047",
#       "fileInfo": {
#         "src_last_modified_millis": "1523812647658"
#       },
#       "fileName": "anole.png",
#       "size": 91619,
#       "uploadTimestamp": 1523813235000
#     },
#     {
#       "action": "upload",
#       "contentLength": 0,
#       "contentSha1": "da39a3eeefb5486a3255bfef95601890afd80709",
#       "contentType": "text/plain",
#       "fileId": "4_z84c14bea3e43f5c56c21061e_d20180415_m172906_c002_v0001095_t0021",
#       "fileInfo": {},
#       "fileName": "imageuploader/.bzEmpty",
#       "size": 0,
#       "uploadTimestamp": 1523813346000
#     },
#     {
#       "action": "upload",
#       "contentLength": 144087,
#       "contentSha1": "a294eb6e4567abcf1234f4de8906abb1e6906553",
#       "contentType": "image/png",
#       "fileId": "4_z84c14bea3e43f5c56c21061e_d20180415_m173426_c002_v0001095_t0011",
#       "fileInfo": {
#         "src_last_modified_millis": "1523812671419"
#       },
#       "fileName": "imageuploader/butterfly.png",
#       "size": 144087,
#       "uploadTimestamp": 1523813666000
#     },
#     {
#       "action": "upload",
#       "contentLength": 0,
#       "contentSha1": "da39a3ee5e6ef5486ac5bfef95601890afd80709",
#       "contentType": "text/plain",
#       "fileId": "4_z84c14bea3e43f5c56c21061e_d20180415_m172925_c002_v0001095_t0035",
#       "fileInfo": {},
#       "fileName": "sightings/.bzEmpty",
#       "size": 0,
#       "uploadTimestamp": 1523813365000
#     }
#   ],
#   "nextFileName": null
# }


# List all files in bucket that match file name prefix (for all files, use "" for file)
def b2_list_file_names(file)

    auth_hash = convert_json(b2_authorize_account)
    api_url = auth_hash["apiUrl"]
    account_authorization_token = auth_hash["authorizationToken"]
    bucket_id = ENV['bucket_id']
    prefix = file

    uri = URI("#{api_url}/b2api/v1/b2_list_file_names")
    req = Net::HTTP::Post.new(uri)
    req.add_field("Authorization","#{account_authorization_token}")
    req.body = "{\"bucketId\":\"#{bucket_id}\", \"prefix\":\"#{prefix}\"}"
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
# puts b2_list_file_names("nemo.png")
#
# Returns:
# {
#   "files": [
#     {
#       "action": "upload",
#       "contentLength": 121089,
#       "contentSha1": "584db4ab22c60e3ae8bk39d07c22e70fc6eb1c96",
#       "contentType": "image/png",
#       "fileId": "4_z84c14bea3e43f5c56c21061e_d20180419_m002318_c002_v0001094_t0044",
#       "fileInfo": {},
#       "fileName": "nemo.png",
#       "size": 121089,
#       "uploadTimestamp": 1524097398000
#     }
#   ],
#   "nextFileName": null
# }


# Create a hash of file names + file IDs
def parse_files_json(file)

    files_hash = convert_json(b2_list_file_names(file))
    files = {}

    files_hash["files"].each do |file_hash|
        files[file_hash["fileName"]] = file_hash["fileId"]
    end

    return files

end

# Command:
# pp parse_files_json("")
#
# Returns:
# {
#     "anole.png"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172715_c002_v0001095_t0047",
#     "imageuploader/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172906_c002_v0001095_t0021",
#     "nemo.png"=>"4_z84c14bea3e43f5c56c21061e_d20180420_m012138_c002_v0001094_t0058",
#     "sightings/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172925_c002_v0001095_t0035"
# }
#
# Command:
# pp parse_files_json("nemo.png")
#
# Returns:
# {
    # "nemo.png"=>"4_z84c14bea3e43f5c56c21061e_d20180420_m012138_c002_v0001094_t0058"
# }
#
# Command:
# pp parse_files_json("not in the bucket")
#
# Returns:
# {}


# Get information for the specified file ID
def b2_get_file_info(file_id)

    auth_hash = convert_json(b2_authorize_account)
    api_url = auth_hash["apiUrl"]
    account_authorization_token = auth_hash["authorizationToken"]

    uri = URI.join("#{api_url}/b2api/v1/b2_get_file_info")
    req = Net::HTTP::Post.new(uri)
    req.add_field("Authorization","#{account_authorization_token}")
    req.body = "{\"fileId\":\"#{file_id}\"}"
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
# puts b2_get_file_info("4_z84c14bea3e43f5c56c21061e_d20180420_m012138_c002_v0001094_t0058")
#
# Returns:
# {
#   "accountId": "41b5243de1ae",
#   "action": "upload",
#   "bucketId": "84c14bea3e43f5c56c21061e",
#   "contentLength": 121089,
#   "contentSha1": "584db4ab22c60e3ae8bk39d07c22e70fc6eb1c96",
#   "contentType": "image/png",
#   "fileId": "4_z84c14bea3e43f5c56c21061e_d20180420_m012138_c002_v0001094_t0058",
#   "fileInfo": {},
#   "fileName": "nemo.png",
#   "uploadTimestamp": 1524187298000
# }


# Create URL for specified B2 file, optional folder(s)
def b2_generate_file_url(file, *folder)

    subdir = "#{folder[0]}/" if folder[0] != nil
    # return "https://f002.backblazeb2.com/file/portfolio-jv/#{subdir}#{file}"
    return "#{ENV['download_url']}#{subdir}#{file}"

end

# Commands:
# puts b2_generate_file_url("nemo.png")
# puts b2_generate_file_url("butterfly.png", "imageuploader")
#
# Returns:
# https://f002.backblazeb2.com/file/portfolio-jv/nemo.png
# https://f002.backblazeb2.com/file/portfolio-jv/imageuploader/butterfly.png


# Create an array of URLs for all files specified in query
# - the parameter is the Mysql2::Client database connection
# - note that this doesn't verify files are in the bucket, just the DB
def query_b2(client)

    urls = []
    results = client.query("select photo from testing")

    results.each do |result|
        file = result["photo"]
        url = b2_generate_file_url(file)
        urls.push(url)
    end

    return urls

end

# Command:
# pp query_b2(client)
#
# Result:
# [
#     "https://f002.backblazeb2.com/file/portfolio-jv/redfish.png",
#     "https://f002.backblazeb2.com/file/portfolio-jv/bluefish.png",
#     "https://f002.backblazeb2.com/file/portfolio-jv/oldfish.png",
#     "https://f002.backblazeb2.com/file/portfolio-jv/newfish.png"
# ]


# Get prerequisite values for uploading a file to B2 bucket
def b2_get_upload_url()

    auth_hash = convert_json(b2_authorize_account)
    api_url = auth_hash["apiUrl"]
    account_authorization_token = auth_hash["authorizationToken"]
    bucket_id = ENV['bucket_id']

    uri = URI("#{api_url}/b2api/v1/b2_get_upload_url")
    req = Net::HTTP::Post.new(uri)
    req.add_field("Authorization","#{account_authorization_token}")
    req.body = "{\"bucketId\":\"#{bucket_id}\"}"
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
# puts b2_get_upload_url()
#
# Returns:
# {
#   "authorizationToken": "3_201865e2fd1700_4501015f0bca9c3ea234fea27c482080707a780e_002_acct",
#   "bucketId": "84c14bea3e43f5c56c21061e",
#   "uploadUrl": "https://pod-000-1096-11.backblaze.com/b2api/v1/b2_upload_file/84c14bea3e43f5c56c21061e/c002_v0001096_t0003"
# }


# Generate the SHA1 hash for the specified file (point to /path/file)
def generate_sha(file)

    sha1 = Digest::SHA1.file file
    return sha1

end

# Command:
# puts generate_sha("nemo.png")
#
# Returns:
# 584db4ab22c60e3ae8bk39d07c22e70fc6eb1c96


# Upload file to b2 bucket
def b2_upload_file(file)

    upload_url_hash = convert_json(b2_get_upload_url)

    upload_url = upload_url_hash["uploadUrl"] + "/imageuploader"
    upload_authorization_token = upload_url_hash["authorizationToken"]
    file_sha1 = generate_sha(file)
    file_length = File.size(file)
    file_data = File.open(file, "rb") { |io| io.read }

    uri = URI(upload_url)
    req = Net::HTTP::Post.new(uri)
    req.add_field("Authorization", upload_authorization_token)
    req.add_field("X-Bz-File-Name", file)
    req.add_field("Content-Type", "b2/x-auto")
    req.add_field("X-Bz-Content-Sha1", file_sha1)
    req.add_field("Content-Length", file_length)
    req.body = file_data
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = (req.uri.scheme == 'https')
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
# b2_upload_file("nemo.png")
# pp parse_files_json("")
#
# Returns:
# {
#   "accountId": "41b5243de1ae",
#   "action": "upload",
#   "bucketId": "84c14bea3e43f5c56c21061e",
#   "contentLength": 121089,
#   "contentSha1": "584db4ab22c60e3ae8bk39d07c22e70fc6eb1c96",
#   "contentType": "image/png",
#   "fileId": "4_z84c14bea3e43f5c56c21061e_d20180418_m021504_c002_v0001096_t0052",
#   "fileInfo": {},
#   "fileName": "nemo.png",
#   "uploadTimestamp": 1524017704000
# }


# Checks if file is already in bucket before attempting to upload
# - to upload an image into a folder, need to make sure the same directory exists locally so file can be reached
#   ex: backblaze.rb file called from C:\b2, image path needs to be C:\b2\imageuploader\butterfly.png
def save_file_to_b2_bucket(file)

    result = parse_files_json(file)

    if result == {}  # file exists
        b2_upload_file(file)
        # cleanup_swap_dir(file)
        return "Image uploaded to bucket!"
    else
        # cleanup_swap_dir(file)
        return "Image already in bucket!"
    end

end

# Commands:
# pp parse_files_json("")
# puts "File already in bucket..."
# puts save_file_to_b2_bucket("anole.png")
# puts "File not already in bucket..."
# puts save_file_to_b2_bucket("nemo.png")
# puts "File and folder not already in bucket..."
# puts save_file_to_b2_bucket("imageuploader/butterfly.png")
# pp parse_files_json("")
#
# Returns:
# {
#     "anole.png"=>"4_z84c14bea3e43f5c56c21061e__d20180415_m172715_c002_v0001095_t0047",
#     "imageuploader/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172906_c002_v0001095_t0021",
#     "sightings/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172925_c002_v0001095_t0035"
# }
# File already in bucket...
# Image already in bucket!
# File not already in bucket...
# Image uploaded to bucket!
# File and folder not already in bucket...
# Image uploaded to bucket!
# {
#     "anole.png"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172715_c002_v0001095_t0047",
#     "imageuploader/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172906_c002_v0001095_t0021",
#     "imageuploader/butterfly.png"=>"4_z84c14bea3e43f5c56c21061e_d20180420_m020624_c002_v0001095_t0017",
#     "nemo.png"=>"4_z84c14bea3e43f5c56c21061e_d20180420_m012138_c002_v0001094_t0058",
#     "sightings/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172925_c002_v0001095_t0035"
# }


# Download file from B2 bucket by name
def b2_download_file_by_name(file, *folder)

    if folder[0] != nil
        file_url = b2_generate_file_url(file, folder[0])
    else
        file_url = b2_generate_file_url(file)
    end

    uri = URI(file_url)
    req = Net::HTTP::Get.new(uri)
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then
            res.body
            swapfile = File.new("./public/swap/#{file}", 'wb')
            swapfile.puts(res.body)
            swapfile.close
        when Net::HTTPRedirection then
            fetch(res['location'], limit - 1)
        else
            res.error!
    end

end

# Commands:
# b2_download_file_by_name("nemo.png")
# b2_download_file_by_name("nemo.png")
#
# Returns:
# res.body is a binary string, output is files saved to directory


# Delete the specific file
# - throws a 404 error if file doesn't exist, so use b2_delete_file() which wraps this method
def b2_delete_file_version(file)

    auth_hash = convert_json(b2_authorize_account)
    api_url = auth_hash["apiUrl"]
    account_authorization_token = auth_hash["authorizationToken"]

    file_hash = parse_files_json(file)
    file_name = file
    file_id = file_hash[file]

    uri = URI("#{api_url}/b2api/v1/b2_delete_file_version")
    req = Net::HTTP::Post.new(uri)
    req.add_field("Authorization","#{account_authorization_token}")
    req.body = "{\"fileName\":\"#{file_name}\", \"fileId\":\"#{file_id}\"}"
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req)}

    case res
        when Net::HTTPSuccess then res.body
        when Net::HTTPRedirection then fetch(res['location'], limit - 1)
        else res.error!
    end

end

# Command:
# b2_delete_file_version("nemo.png")
#
# Returns:
# {
#   "fileId": "4_z84c14bea3e43f5c56c21061e_d20180419_m002318_c002_v0001094_t0044",
#   "fileName": "nemo.png"
# }


# Verifies file is present before attempting to delete
# - file parameter only targets files in root of bucket if only "filename" is provided
# - file parameter needs to be "folder/filename" if file exists inside bucket folder
def b2_delete_file(file)

    if parse_files_json(file) == {}

        return "File not present"

    else
        
        result_hash = convert_json(b2_delete_file_version(file))

        if result_hash["fileName"] == file
            return "File deleted successfully"
        else
            return "Error deleting file"
        end

    end

end

# Commands:
# pp parse_files_json("")
# puts b2_delete_file("nemo.png")
# puts b2_delete_file("imageuploader/butterfly.png")
# puts b2_delete_file("not in bucket")
# pp parse_files_json("")
#
# Returns:
# {
#     "anole.png"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172715_c002_v0001095_t0047",
#     "imageuploader/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172906_c002_v0001095_t0021",
#     "imageuploader/butterfly.png"=>"4_z84c14bea3e43f5c56c21061e_d20180420_m020624_c002_v0001095_t0017",
#     "nemo.png"=>"4_z84c14bea3e43f5c56c21061e_d20180420_m021814_c002_v0001094_t0058",
#     "sightings/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172925_c002_v0001095_t0035"
# }
# File deleted successfully
# File deleted successfully
# File not present
# {
#     "anole.png"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172715_c002_v0001095_t0047",
#     "imageuploader/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172906_c002_v0001095_t0021",
#     "sightings/.bzEmpty"=>"4_z84c14bea3e43f5c56c21061e_d20180415_m172925_c002_v0001095_t0035"
# }
#!/usr/bin/ruby

require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'
require 'certified'
require 'Trollop'


class Youtube_Helper

  @@client_email = '' #email id from service account (that really long email address...)
  @@youtube_email = '' #email associated with youtube account
  @@p12_file_path = '' #path to the file downloaded from the service account (Generate new p12 key button)
  @@p12_password = '' # password to the file usually 'notasecret'
  YOUTUBE_UPLOAD_SCOPE = 'https://www.googleapis.com/auth/youtube.upload'
  YOUTUBE_API_SERVICE_NAME = 'youtube'
  YOUTUBE_API_VERSION = 'v3'
  @@client = nil
  @@youtube = nil

  def initialize(client_email, youtube_email, p12_file_path, p12_password)
    @@client_email=client_email
    @@youtube_email=youtube_email
    @@p12_file_path=p12_file_path
    @@p12_password=p12_password
    @@client, @@youtube = get_authenticated_service
  end

  def get_authenticated_service
    puts 'authenticate'
    # puts @PROGRAM_NAME.to_s + ' client email ' + @@client_email.to_s + ' youtube email ' + @@youtube_email.to_s + ' p12 file path ' + @@p12_file_path.to_s + ' p12 password ' + @@p12_password.to_s
    api_client = Google::APIClient.new(
      :application_name => $PROGRAM_NAME,
      :application_version => '1.0.0',

    )
    
    puts 'get key'
    key = Google::APIClient::KeyUtils.load_from_pkcs12(@@p12_file_path, @@p12_password)
    auth_client = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => YOUTUBE_UPLOAD_SCOPE,
      :issuer => @@client_email,
      :person => @@youtube_email,
      :signing_key => key)
    auth_client.fetch_access_token!
    api_client.authorization = auth_client
    puts 'got client'
    youtube = api_client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
    puts 'got youtube'
    return api_client, youtube
  end

  def upload2youtube file, title, description, category_id, keywords, privacy_status
    puts 'begin'
    begin
      body = {
        :snippet => {
          :title => title,
          :description => description,
          :tags => keywords.split(','),
          :categoryId => category_id,
        },
        :status => {
          :privacyStatus => privacy_status
        }
      }
      puts body.keys.join(',')

      # Call the API's videos.insert method to create and upload the video.
      videos_insert_response = @@client.execute!(
        :api_method => @@youtube.videos.insert,
        :body_object => body,
        :media => Google::APIClient::UploadIO.new(file, 'video/*'),
        :parameters => {
          'uploadType' => 'multipart',
          :part => body.keys.join(',')
        }
      )

      puts'inserted'
      # videos_insert_response.resumable_upload.send_all(client)
      
      puts "'#{videos_insert_response.data.snippet.title}' (video id: #{videos_insert_response.data.id}) was successfully uploaded."

    rescue Google::APIClient::TransmissionError => e
      puts e.result.body
    end

    return videos_insert_response.data.id #video id
    
  end

  def upload_thumbnail  video_id, thumbnail_file, thumbnail_size
    puts 'uploading thumbnail'
    begin
      thumbnail_upload_response = @@client.execute!({ :api_method => @@youtube.thumbnails.set,
                              :parameters => { :videoId => video_id,
                                               'uploadType' => 'media',
                                               :onBehalfOfContentOwner => @@youtube_email},
                              :media => thumbnail_file,
                              :headers => { 'Content-Length' => thumbnail_size.to_s,
                                            'Content-Type' => 'image/jpg' }
                              })
      puts 'finished uploading thumbnail'
    rescue Google::APIClient::TransmissionError => e
        puts e.result.body 
    end 
  end
end

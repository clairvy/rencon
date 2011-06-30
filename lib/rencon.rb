require 'rubygems'
require 'mechanize'
require 'kconv'
require 'csv'

module Rencon

  class Ticket
    attr_reader :number, :status, :project
    attr_reader :tracker, :priority, :subject
    attr_reader :assigned_to, :category
    attr_reader :target_version, :author
    attr_reader :start, :due_date, :done_rate
    attr_reader :estimated_time, :created_at
    attr_reader :updated_at, :description

    def self.new_with_order(values, order)
      issue = new
      values.each_with_index do |v, i|
        issue.instance_variable_set("@#{order[i]}", v)
      end
      issue
    end

    private_class_method :new
  end

  class Core

    attr_reader :states

    def initialize(config)
      check(config) or raise 'Invalid configuration'
      @config = config
      @states  = nil
      @agent  = Mechanize.new
      @agent.user_agent = 'Mac Safari'
      login
    end

    def retrieve(project, per_page = 25)
      title = @agent.get("http://#{conf(:host)}/projects/show/#{project}").title.sub(/\s-.*\z/, '')

      per_page = conf(:per_page) || per_page
      @agent.get "http://#{conf(:host)}/projects/#{project}/issues/?per_page=#{per_page}&format=csv"
      @states, *tickets  = CSV.parse(@agent.page.body.to_s.toutf8).
        # FIXME: Muiltiline descriptions are rounded off to one lines.
        #        #reject can not know correct number of issue's status.
        #        now size < 10, but this is a first aid. need fix rapidly.
        reject {|issue| issue.size < 10 }

      [tickets, title]
    end

    def lambda_mark
      mine = conf(:mark, :mine) || '+'
      none = conf(:mark, :none) || '-'
      lambda {|name| /#{conf(:name)}/ =~ name ? mine : none }
    end

    def mark(name)
      lambda_mark[name]
    end

    private
    def login
      @agent.get "http://#{conf(:host)}/login"
      @agent.page.form_with(:action => '/login') do |f|
        f.field_with(:name => 'username').value = conf(:user)
        f.field_with(:name => 'password').value = conf(:pass)
        f.click_button
      end
    end

    # FIXME: need more check
    def check(config)
      [ :host,
        :user,
        :pass,
        :name,
      ].all? {|key| config.has_key? key }
    end

    def conf(*keys)
      keys.inject(@config, :[]) rescue nil
    end
  end
end


require 'rubygems'
require 'redis'
require 'nest'

class TimedCounter
  def initialize(redis, options = {})
    default_options = {
      minutes: true,
      hours: true,
      days: true,
      months: true,
      years: true
    }

    @redis = redis
    @root = Nest.new("$tc", redis)
    @options = default_options.merge(options)
  end

  def convert_keys(parts)
    if parts.is_a?(Array)
      if parts.length == 1
        return convert_part(parts.first)
      end

      parts.collect { |it| convert_part(it) }.join("/")
    else
      convert_part(parts)
    end
  end

  def convert_part(part)
    if part.respond_to?(:id)
      [part.class.name, part.id].join("#")
    else
      part.to_s
    end
  end

  def make_keys(key)
    if key.is_a?(Array)
      depth = key.length
      result = []

      until depth == 0
        result << convert_keys(key[0, depth])
        depth -= 1
      end

      result
    else
      [convert_part(key)]
    end 
  end

  def make_ts(time)
    (time || Time.now).utc.strftime("%Y%m%d%H%M")
  end

  # redis key to total will be "c:#{key}:total"
  def incr(key, amount = 1, time = nil)
    ts = make_ts(time)

    hour_key = ts[0, 10]
    min = ts[10, 2]

    day_key = ts[0, 8]
    hour = ts[8,2]

    month_key = ts[0, 6]
    day = ts[6,2]

    year_key = ts[0, 4]
    month = ts[4, 2]

    # store values in hashes
    #
    # total: 1
    # years: { 2011: 1, 2010: 0 }
    # 2011: { 01: 0, 02: 0, 03: 1, ... } months
    # 2011-03: { 01: 0, 02: 0, ...} days
    # 2011-03-11: { 00: 0, 01: 0, 02: 0, ...} hours
    # 2011-03-11 11: { 00, 01, 02, ...} minutes
    #
    keys = make_keys(key)

    pipeline = @redis.multi do
      keys.each do |ckey|
        node = @root[ckey]
        node[:total].incrby(amount)

        if @options[:years]
          node[:years].hincrby(year_key, amount)
        end

        if @options[:months]
          node[year_key].hincrby(month, amount)
        end

        if @options[:days]
          node[month_key].hincrby(day, amount)
        end

        if @options[:hours]
          node[day_key].hincrby(hour, amount)
        end

        if @options[:minutes]
          node[hour_key].hincrby(min, amount)
        end
      end
    end

    result = pipeline.last

    # if the total count equals our amount we created this key, so keep a list of active counters
    if result[0] == amount
      keys.each do |ckey|
        @redis.sadd("$tc_list", ckey)
      end
    end

    # for now just keep everything, time will tell how much data we are talking about
    # set_expires(result, amount)

    result[0]
  end

  # only set expires when the the counter state == amount aka. we created it.
  def set_expires(result, amount)
    if result[0] == amount
      # total was new
    end

    if result[1] == amount
      # years/year was new
    end

    if result[2] == amount
      # year/month was new
    end

    if result[3] == amount
      # month/day was new
    end

    # keep hour precision data for 180 days?
    if result[4] == amount
      # day/hour was new
      @root[hour_key].expire(86400 * 180) # expire in 180 days?
    end

    # keep minute precision data for 30 days?
    if result[5] == amount
      # hour/min was new
      @root[hour_key].expire(86400 * 30) # expire in 180 days?
    end

    true
  end

  def reset!(key)
    make_keys(key).each do |ckey|
      @redis.keys("#{@root[ckey]}*").each do |c|
        @redis.del(c)
      end
    end
  end


  # start timestamp
  # count number of steps
  # step_size number of seconds to increment steps
  # ts_index index in 201103111200
  def query_hash_range(key, start, count, step_size, ts_index, ts_size = 2)
    hash = Hash.new { |h, k| h[k] = [] }
    count.times do |it|
      ts = make_ts(start + (it * step_size))
      hash[ts[0, ts_index]] << ts[ts_index, ts_size]
    end

    ckey = convert_keys(key)
    node = @root[ckey]

    keys = hash.to_a.sort_by { |it| it[0] }
    mres = @redis.pipelined do
      keys.each do |key, values|
        node[key].hmget(*values)
      end
    end

    mres.flatten.collect(&:to_i)
  end

  def total(key)
    @root[convert_keys(key)][:total].get.to_i
  end

  def year(key, time = nil)
    @root[convert_keys(key)][:years].hget(make_ts(time)[0, 4]).to_i
  end

  def month(key, time = nil)
    ts = make_ts(time)
    @root[convert_keys(key)][ts[0, 4]].hget(ts[4, 2]).to_i
  end

  def day(key, time = nil)
    ts = make_ts(time)
    @root[convert_keys(key)][ts[0, 6]].hget(ts[6, 2]).to_i
  end

  def days(key, start, count)
    query_hash_range(key, start, count, 60*60*24, 6, 2)
  end

  def hour(key, time = nil)
    ts = make_ts(time)
    @root[convert_keys(key)][ts[0, 8]].hget(ts[8, 2]).to_i
  end

  def hours(key, start, count)
    query_hash_range(key, start, count, 60*60, 8, 2)
  end

  def minute(key, time = nil)
    ts = make_ts(time)
    @root[convert_keys(key)][ts[0, 10]].hget(ts[10, 2]).to_i
  end

  def minutes(key, start, count)
    query_hash_range(key, start, count, 60, 10, 2)
  end
end

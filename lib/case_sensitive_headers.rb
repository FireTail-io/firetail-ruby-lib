class CustomPost < Net::HTTP::Post
    def initialize_http_header(headers)
      @header = {}
      headers.each { |k, v| @header[k.to_s] = [v] }
    end

    def [](name)
      _k, val = header_insensitive_match name
      val
    end

    def []=(name, val)
      key, _val = header_insensitive_match name
      key = name if key.nil?
      if val
        @header[key] = [val]
      else
        @header.delete(key)
      end
    end

    def capitalize(name)
      name
    end

    def header_insensitive_match(name)
      @header.find { |key, _value| key.match Regexp.new(name.to_s, Regexp::IGNORECASE) }
    end
end

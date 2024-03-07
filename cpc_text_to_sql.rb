# frozen_string_literal: true

require 'debug'

# Export CPC Classifications to SQL
class CpcTextToSQL
  def initialize(fname)
    @fname = fname
  end

  def parse
    section, subsection, subclass, group, subgroup, subsubgroup = File.foreach(@fname).first(6).map do |record|
      record.split("\t").reject(&:empty?).map(&:strip).map { |str| format(str) }
    end

    # symbol, name = section.split("\t", 2).map(&:split)

    binding.b

    # File.foreach(@fname) do |line|
    #   process_line(line)
    # end
  end

  private

  def process_line(line); end

  def format(str)
    str.strip.gsub(/\s+/, ' ').gsub(/[{}()]/, '')
  end
end

CpcTextToSQL.new('./text/cpc-section-A_20240101.txt').parse

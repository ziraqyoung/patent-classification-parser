require 'json'
require 'debug'
require 'nokogiri'

# Parses XML CPC classifications to JSON
class CpcParser
  def initialize(xml_fname)
    @xml_fname = xml_fname
    @json = {}
  end

  def parse
    doc = Nokogiri::XML(File.read(@xml_fname))
    root = doc.root
    item = root.elements.first
    parse_level2(item)
  end

  def self.export_to_json(hash, fname)
    File.open("json/#{fname}", 'w') do |f|
      f.write(JSON.pretty_generate(hash))
    end
  end

  def parse_level2(item)
    symbol = find_symbol item
    title = build_title item
    nodes = select_items(item)

    level3_items = nodes.collect { |node| parse_level3(node) }

    format_hash(
      {
        'cpcSectionCode' => symbol.text,
        'cpcSectionName' => format_text(title),
        'cpcSubsections' => level3_items
      }
    )
  end

  def parse_level3(item)
    title = build_title(item)
    nodes = select_items(item)

    level4_items = nodes.collect { |node| parse_level4(node) }

    format_hash(
      {
        'cpcSubsectionName' => format_text(title),
        'cpcClasses' => level4_items
      }
    )
  end

  def parse_level4(item)
    symbol = find_symbol(item)
    title = build_title(item)

    nodes = select_items item
    level5_items = nodes.collect { |node| parse_level5(node) }

    format_hash(
      {
        'cpcClassCode' => symbol.text,
        'cpcClassName' => format_text(title),
        'cpcSubClasses' => level5_items
      }
    )
  end

  # NOTE: has `notes-and-warning` if needed
  def parse_level5(item)
    symbol = find_symbol item
    title = build_title item

    link_file = item['link-file']

    # may be save `notes and warning`
    format_hash(
      {
        'cpcSubClassCode' => symbol.text,
        'cpcSubClassName' => format_text(title),
        'cpcGroups' => parse_link_file(link_file)
      }
    )
  end

  # NOTE: Good place to find <reference>
  def parse_link_file(link_file)
    fname = File.join File.dirname(@xml_fname), link_file
    doc = Nokogiri::XML(File.read(fname))
    root = doc.root
    item = root.elements.first
    prefix = find_symbol item

    # ignore 6 and jump to 7 - which introduces a group
    # levels 8 and 9 are the subgroups
    groups = []

    level6_items = select_items item

    # TODO: maybe concat title here (some have <A01B3/00>, some don't <A01B1/00>)...IGNORE
    level6_items.each do |six|
      sevens = select_items six

      sevens.each do |seven|
        groups << parse_level7(prefix, seven)
      end

      # TODO: figure this out
      # sevens = select_items six
      # level7_items = nodes.collect { |node| parse_level7(prefix, node) }
    end

    groups
  end

  def parse_level7(prefix, item)
    symbol = find_symbol item
    title = build_title item

    nodes = select_items item
    level8_items = nodes.collect { |node| parse_level8(node) }

    format_hash(
      {
        'cpcGroupCode' => symbol.text.sub(prefix, ''),
        'cpcGroupName' => format_text(title),
        'cpcSubGroups' => level8_items
      }
    )
  end

  def parse_level8(item)
    symbol = find_symbol item
    title = build_title item

    nodes = select_items item
    level9_items = nodes.collect { |node| parse_level9(node) }

    format_hash(
      {
        'cpcSubGroupCode' => symbol.text,
        'cpcSubGroupName' => format_text(title),
        'cpcLevel1SubGroups' => level9_items
      }
    )
  end

  def parse_level9(item)
    symbol = find_symbol item
    title = build_title item

    nodes = select_items item
    level10_items = nodes.collect { |node| parse_level10(node) }

    # binding.b if symbol.text == 'A01B1/028'

    format_hash(
      {
        'cpcLevel1SubGroupCode' => symbol.text,
        'cpcLevel1SubGroupName' => format_text(title),
        'cpcLevel2SubGroups' => level10_items
      }
    )
  end

  def parse_level10(item)
    symbol = find_symbol item
    title = build_title item

    nodes = select_items item
    level11_items = nodes.collect { |node| parse_level11(node) }

    # binding.b if symbol.text == 'A01B1/028'

    format_hash(
      {
        'cpcLevel2SubGroupCode' => symbol.text,
        'cpcLevel2SubGroupName' => format_text(title),
        'cpcLevel3SubGroups' => level11_items
      }
    )
  end

  def parse_level11(item)
    symbol = find_symbol item
    title = build_title item

    nodes = select_items item
    level12_items = nodes.collect { |node| parse_level12(node) }

    # binding.b if symbol.text == 'A01B1/028'

    format_hash(
      {
        'cpcLevel3SubGroupCode' => symbol.text,
        'cpcLevel3SubGroupName' => format_text(title),
        'cpcLevel4SubGroups' => level12_items
      }
    )
  end

  def parse_level12(item)
    symbol = find_symbol item
    title = build_title item

    format_hash({ 'cpcLevel4SubGroupCode' => symbol.text, 'cpcLevel4SubGroupName' => format_text(title) })
  end

  def find_symbol(item)
    item.elements.find { |child| child.name == 'classification-symbol' }
  end

  def find_title(item)
    title = item.elements.find { |child| child.name == 'class-title' }

    # check if first-level nested has <classification-item> that has <class-title>
    # Handle A99 classification
    if (symbol = find_symbol(item)) && !title
      node = select_items(item).first
      nested_symbol = find_symbol(node)
      if nested_symbol.text == symbol.text
        title = node.elements.find do |child|
          child.name == 'class-title' && child.elements
        end
      end
    end

    title
  end

  def build_title(item)
    node = find_title(item)

    title_strings = node.elements.collect do |title_part|
      title_part.elements.find { |child| child.search('text') }&.text&.strip
    end

    title_strings.join('; ')
  end

  def select_items(item)
    item.elements.select { |child| child.name == 'classification-item' }
  end

  def format_hash(hash)
    hash.compact.delete_if { |_k, v| v.empty? }
  end

  def format_text(text)
    text&.strip&.gsub(/\s+/, ' ')
  end
end

class ExportToSingle
  XML_FNAMES = ['cpc-scheme-A.xml'].freeze
  # XML_FNAMES = ['cpc-scheme-A.xml', 'cpc-scheme-B.xml', 'cpc-scheme-C.xml', 'cpc-scheme-D.xml', 'cpc-scheme-E.xml',
  #               'cpc-scheme-F.xml', 'cpc-scheme-G.xml', 'cpc-scheme-H.xml', 'cpc-scheme-Y.xml'].freeze
  def initialize
    @json = { 'cpcSections' => [] }
  end

  def export
    xml_fnames.map do |xml_fname|
      puts "==== Parsing <#{xml_fname}> ===="
      @json['cpcSections'].push(CpcParser.new("./data/#{xml_fname}").parse)
      puts '.... Done  ===='
    end

    puts '==== Saving ===='
    export_to_one_file(@json)
    puts '==== Fininshed export ===='
  end

  def export_to_one_file(hash)
    File.open('all.json', 'w') do |f|
      f.write(JSON.pretty_generate(hash))
    end
  end

  def xml_fnames
    XML_FNAMES
  end
end

def parse_all
  puts '==== Staring export ===='
  # xml_fnames = ['cpc-scheme-A.xml']

  xml_fnames = ['cpc-scheme-A.xml', 'cpc-scheme-B.xml', 'cpc-scheme-C.xml', 'cpc-scheme-D.xml', 'cpc-scheme-E.xml',
                'cpc-scheme-F.xml', 'cpc-scheme-G.xml', 'cpc-scheme-H.xml', 'cpc-scheme-Y.xml']

  xml_fnames.each do |xml_fname|
    puts "==== Parsing <#{xml_fname}> ===="

    json_fname = xml_fname.split('-').last.sub('xml', 'json')

    @obj = CpcParser.new("./data/#{xml_fname}").parse

    CpcParser.export_to_json(@obj, json_fname)

    puts ".... Done writting: <#{json_fname}> ===="
  end
  puts '==== Fininshed export ===='
end

parse_all

# @full_json = ExportToSingle.new
# @full_json.export

if __FILE__ == $0
  require 'minitest/autorun'
  require 'debug'

  # Test CpcParser
  # class CpcParserTest < Minitest::Test
  #   def setup
  #     @obj = CpcParser.new('./test/cpc-scheme-A.xml').parse
  #     @sections = @obj['cpcSections']
  #     @first_section = @sections[0] # A
  #     @sub0 = @first_section[0]
  #   end
  #
  #   def test_export_to_json
  #     # assert CpcParser.export_to_json(@obj, @first_section['cpcSectionCode'])
  #   end
  #
  #   def test_correct_structure
  #     assert_instance_of Hash, @obj
  #     assert_instance_of Array, @obj['cpcSections']
  #   end
  #
  #   def test_first_section
  #     assert_equal 'A', @first_section['cpcSectionCode']
  #     assert_equal 'HUMAN NECESSITIES', @first_section['cpcSectionName']
  #     assert_instance_of Array, @first_section['cpcSubSections']
  #   end
  #
  #   def test_subsections
  #     # assert_equal 'Agriculture', @sub0['cpcSubSectionName']
  #   end
  # end
end

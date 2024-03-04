require 'nokogiri'
require 'json'
require 'debug'

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
    title = find_title item
    nodes = select_items(item)

    level3_items = nodes.collect { |node| parse_level3(node) }

    {
      'cpcSectionCode' => symbol.text,
      'cpcSectionName' => title,
      'cpcSubSections' => level3_items
    }
  end

  def parse_level3(item)
    title = find_title(item)
    nodes = select_items(item)

    level4_items = nodes.collect { |node| parse_level4(node) }

    {
      'cpcSubSectionName' => (title unless title.nil?),
      'cpcClasses' => level4_items
    }.compact
  end

  def parse_level4(item)
    symbol = find_symbol(item)
    title = build_title(item)

    nodes = select_items item
    level5_items = nodes.collect { |node| parse_level5(node) }

    {
      'cpcClassCode' => symbol.text,
      'cpcClassName' => title,
      'cpcSubSections' => level5_items
    }
  end

  # NOTE: has `notes-and-warning` if needed
  def parse_level5(item)
    symbol = find_symbol item
    title = build_title item

    link_file = item['link-file']

    # may be save `notes and warning`
    {
      'cpcSubClassCode' => symbol.text,
      'cpcSubClassName' => title,
      'cpcGroups' => parse_link_file(link_file)
    }
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

    # flattened = item.search 'classification-item'

    # stripped = flattened.collect do |child|

    #   [child['sort-key'], build_title(child) ]
    # end

    {
      'cpcGroupCode' => symbol.text.sub(prefix, ''),
      'cpcGroupName' => title,
      'cpcSubGroups' => level8_items
    }
  end

  def parse_level8(item)
    symbol = find_symbol item
    title = item.elements.find { |child| child.name == 'class-title' }

    title_parts = title.search('text').map(&:text).join('; ')
    j
    nodes = select_items item
    level9_items = nodes.collect { |node| parse_level9(node) }

    # [symbol.text, title_parts]
    {
      'cpcSubGroupCode' => symbol.text,
      'cpcSubGroupName' => title_parts,
      'cpcSubSubGroup' => level9_items
    }
  end

  def parse_level9(item)
    symbol = find_symbol item
    title = find_title item

    # binding.b if symbol.text == 'A01B1/028'

    {
      'cpcSubdivisionCode' => symbol.text,
      'cpcSubdivisionName' => title
    }
  end

  def find_symbol(item)
    item.elements.find { |child| child.name == 'classification-symbol' }
  end

  def find_title(item)
    title = find_title_from_class_title(item) # || find_title_from_nested_classification_item(item)

    title&.text&.strip&.gsub(/\s+/, ' ')
  end

  def find_title_from_class_title(item)
    item.elements.find { |child| child.name == 'class-title' }
  end

  def find_title_from_nested_classification_item(item)
    inner_items = item.elements.select { |child| child.name == 'classification-item' }

    raise 'Hell, no' if inner_items.length > 1

    find_title_from_class_title(inner_items.first)
  end

  def build_title(item)
    node = item.elements.find { |child| child.name == 'class-title' }

    title_strings = node.elements.collect do |title_part|
      title_part.elements.find { |child| child.name == 'text' }&.text&.strip&.gsub(/\s+/, ' ')
    end
    title_strings.join('; ')
  end

  def select_items(item)
    item.elements.select { |child| child.name == 'classification-item' }
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

@full_json = ExportToSingle.new
@full_json.export

def parse_all
  puts '==== Staring export ===='
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
# parse_all

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

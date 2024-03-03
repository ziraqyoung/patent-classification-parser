require 'nokogiri'
require 'json'

# Parses XML CPC classifications to JSON
class CpcParser
  def initialize(xml_fname)
    @xml_fname = xml_fname
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
      'cpcSections' => [
        'cpcSectionNumber' => symbol&.text&.strip,
        'cpcSectionName' => title&.text&.strip,
        'cpcSubSections' => level3_items
      ]
    }
  end

  def parse_level3(item)
    # cpcSubSectionName =>
    title = find_title(item)
    nodes = select_items(item)

    level4_items = nodes.collect { |node| parse_level4(node) }

    {
      'cpcSubSectionName' => (title.nil? ? 'NOT PROVIDED' : title.text.strip.gsub(/\s+/, ' ')),
      'cpcClasses' => level4_items
    }
  end

  def parse_level4(item)
    symbol = find_symbol(item)
    title = build_title(item)

    nodes = select_items item
    level5_items = nodes.collect { |node| parse_level5(node) }

    {
      'cpcClassNumber' => symbol.text,
      'cpcClassName' => title,
      'cpcSubSections' => level5_items
    }
  end

  def parse_level5(item)
    symbol = find_symbol item
    title = build_title item

    link_file = item['link-file']

    {
      'cpcSubClassNumber' => symbol.text,
      'cpcSubClassName' => title,
      'cpcGroups' => parse_link_file(link_file)
    }
  end

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
    level6_items.each do |six|
      sevens = select_items six
      sevens.each do |seven|
        groups << parse_level7(prefix, seven)
      end
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
      'cpcGroupNumber' => symbol.text.sub(prefix, ''),
      'cpcGroupName' => title,
      'cpcSubGroups' => level8_items
    }
  end

  def parse_level8(item)
    symbol = find_symbol item
    title = find_title item

    title_parts = title.search('text').map(&:text).join('; ')

    [symbol.text, title_parts]
  end

  def find_symbol(item)
    item.elements.find { |child| child.name == 'classification-symbol' }
  end

  def find_title(item)
    find_title_from_class_title(item) # || find_title_from_nested_classification_item(item)
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
    node = find_title(item)
    title_strings = node.elements.collect do |title_part|
      title_part.elements.find { |child| child.name == 'text' }&.text&.strip
    end
    title_strings.join('; ')
  end

  def select_items(item)
    item.elements.select { |child| child.name == 'classification-item' }
  end
end

def parse_all
  puts '==== Staring export ===='
  fnames = ['cpc-scheme-A.xml', 'cpc-scheme-B.xml', 'cpc-scheme-C.xml', 'cpc-scheme-D.xml', 'cpc-scheme-E.xml',
            'cpc-scheme-F.xml', 'cpc-scheme-G.xml', 'cpc-scheme-H.xml', 'cpc-scheme-Y.xml']
  j
  fnames.each do |fname|
    puts "==== Parsing #{fname} ===="
    @obj = CpcParser.new("./data/#{fname}").parse
    json_fname = "#{@obj['cpcSections'][0]['cpcSectionNumber']}.json"

    CpcParser.export_to_json(@obj, json_fname)
    puts ".... Done ===="
  end
  puts '==== Fininshed export ===='
end
parse_all

if __FILE__ == $0
  require 'minitest/autorun'
  require 'debug'

  # Test CpcParser
  class CpcParserTest < Minitest::Test
    def setup
      @obj = CpcParser.new('./test/cpc-scheme-A.xml').parse
      @sections = @obj['cpcSections']
      @first_section = @sections[0] # A
      @sub0 = @first_section[0]
    end

    def test_export_to_json
      # assert CpcParser.export_to_json(@obj, @first_section['cpcSectionNumber'])
    end

    def test_correct_structure
      assert_instance_of Hash, @obj
      assert_instance_of Array, @obj['cpcSections']
    end

    def test_first_section
      assert_equal 'A', @first_section['cpcSectionNumber']
      assert_equal 'HUMAN NECESSITIES', @first_section['cpcSectionName']
      assert_instance_of Array, @first_section['cpcSubSections']
    end

    def test_subsections
      # assert_equal 'Agriculture', @sub0['cpcSubSectionName']
    end
  end

  def execute_command_line; end

end

require File.dirname(__FILE__) + '/spec_helper'

describe YARD::CodeObjects::Base do
  before { Registry.clear }
  
  it "should return a unique instance of any registered object" do
    obj = ClassObject.new(:root, :Me)
    obj2 = ModuleObject.new(:root, :Me)
    obj.object_id.should == obj2.object_id
    
    obj3 = ModuleObject.new(obj, :Too)
    obj4 = CodeObjects::Base.new(obj3, :Hello)
    obj4.parent = obj
    
    obj5 = CodeObjects::Base.new(obj3, :hello)
    obj4.object_id.should_not == obj5.object_id
  end
  
  it "should recall the block if #new is called on an existing object" do
    o1 = ClassObject.new(:root, :Me) do |o|
      o.docstring = "DOCSTRING"
    end
    
    o2 = ClassObject.new(:root, :Me) do |o|
      o.docstring = "NOT_DOCSTRING"
    end
    
    o1.object_id.should == o2.object_id
    o1.docstring.should == "NOT_DOCSTRING"
    o2.docstring.should == "NOT_DOCSTRING"
  end
  
  it "should convert string into Docstring when #docstring= is set" do
    o = ClassObject.new(:root, :Me) 
    o.docstring = "DOCSTRING"
    o.docstring.should be_instance_of(Docstring)
  end

  it "should allow complex name and convert that to namespace" do
    obj = CodeObjects::Base.new(nil, "A::B")
    obj.namespace.path.should == "A"
    obj.name.should == :B
  end
  
  it "should allow namespace to be nil and not register in the Registry" do
    obj = CodeObjects::Base.new(nil, :Me)
    obj.namespace.should == nil
    Registry.at(:Me).should == nil
  end
  
  it "should allow namespace to be a NamespaceObject" do
    ns = ModuleObject.new(:root, :Name)
    obj = CodeObjects::Base.new(ns, :Me)
    obj.namespace.should == ns
  end
  
  it "should allow :root to be the shorthand namespace of `Registry.root`" do
    obj = CodeObjects::Base.new(:root, :Me)
    obj.namespace.should == Registry.root
  end
  
  it "should not allow any other types as namespace" do
    lambda { CodeObjects::Base.new("ROOT!", :Me) }.should raise_error(ArgumentError)
  end
  
  it "should register itself in the registry if namespace is supplied" do
    obj = ModuleObject.new(:root, :Me)
    Registry.at(:Me).should == obj
    
    obj2 = ModuleObject.new(obj, :Too)
    Registry.at(:"Me::Too").should == obj2
  end
  
  it "should set any attribute using #[]=" do
    obj = ModuleObject.new(:root, :YARD)
    obj[:some_attr] = "hello"
    obj[:some_attr].should == "hello"
  end
  
  it "#[]= should use the accessor method if available" do
    obj = CodeObjects::Base.new(:root, :YARD)
    obj[:source] = "hello"
    obj.source.should == "hello"
    obj.source = "unhello"
    obj[:source].should == "unhello"
  end
  
  it "should set attributes via attr= through method_missing" do
    obj = CodeObjects::Base.new(:root, :YARD)
    obj.something = 2
    obj.something.should == 2
    obj[:something].should == 2
  end
  
  it "should exist in the parent's #children after creation" do
    obj = ModuleObject.new(:root, :YARD)
    obj2 = MethodObject.new(obj, :testing)
    obj.children.should include(obj2)
  end
  
  it "should properly re-indent source starting from 0 indentation" do
    obj = CodeObjects::Base.new(nil, :test)
    obj.source = <<-eof
      def mymethod
        if x == 2 &&
            5 == 5
          3 
        else
          1
        end
      end
    eof
    obj.source.should == "def mymethod\n  if x == 2 &&\n      5 == 5\n    3 \n  else\n    1\n  end\nend"
    
    Registry.clear
    Parser::SourceParser.parse_string <<-eof
      def key?(key)
        super(key)
      end
    eof
    Registry.at('#key?').source.should == "def key?(key)\n  super(key)\nend"

    Registry.clear
    Parser::SourceParser.parse_string <<-eof
        def key?(key)
          if x == 2
            puts key
          else
            exit
          end
        end
    eof
    Registry.at('#key?').source.should == "def key?(key)\n  if x == 2\n    puts key\n  else\n    exit\n  end\nend"
  end
  
  it "should not add newlines to source when parsing sub blocks" do
    Parser::SourceParser.parse_string <<-eof
      module XYZ
        module ZYX
          class ABC
            def msg
              hello_world
            end
          end
        end
      end
    eof
    Registry.at('XYZ::ZYX::ABC#msg').source.should == "def msg\n  hello_world\nend"    
  end
  
  it "should handle source for 'def x; end'" do
    Registry.clear
    Parser::SourceParser.parse_string "def x; 2 end"
    Registry.at('#x').source.should == "def x; 2 end"
  end
  
  it "should set file and line information" do
    Parser::SourceParser.parse_string <<-eof
      class X; end
    eof
    Registry.at(:X).file.should == '(stdin)'
    Registry.at(:X).line.should == 1
  end
  
  it "should maintain all file associations when objects are defined multiple times in one file" do
    Parser::SourceParser.parse_string <<-eof
      class X; end
      class X; end
      class X; end
    eof
    
    Registry.at(:X).file.should == '(stdin)'
    Registry.at(:X).line.should == 1
    Registry.at(:X).files.should == [['(stdin)', 1], ['(stdin)', 2], ['(stdin)', 3]]
  end

  it "should maintain all file associations when objects are defined multiple times in multiple files" do
    3.times do |i|
      IO.stub!(:read).and_return("class X; end")
      Parser::SourceParser.new.parse("file#{i+1}.rb")
    end
    
    Registry.at(:X).file.should == 'file1.rb'
    Registry.at(:X).line.should == 1
    Registry.at(:X).files.should == [['file1.rb', 1], ['file2.rb', 1], ['file3.rb', 1]]
  end

  it "should prioritize the definition with a docstring when returning #file" do
    Parser::SourceParser.parse_string <<-eof
      class X; end
      class X; end
      # docstring
      class X; end
    eof
    
    Registry.at(:X).file.should == '(stdin)'
    Registry.at(:X).line.should == 4
    Registry.at(:X).files.should == [['(stdin)', 4], ['(stdin)', 1], ['(stdin)', 2]]
  end
end
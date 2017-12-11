require "../spec_helper"

module Oak
  describe Result do
    describe "#found?" do
      context "a new instance" do
        it "returns false when no payload is associated" do
          result = Result(Nil).new
          result.found?.should be_false
        end
      end

      context "with a payload" do
        it "returns true" do
          tree = Tree(Symbol).new("/", :root)
          result = Result(Symbol).new
          result.use tree

          result.found?.should be_true
        end
      end
    end

    describe "#key" do
      context "a new instance" do
        it "returns an empty key" do
          result = Result(Nil).new
          result.key.should eq("")
        end
      end

      context "given one used tree" do
        it "returns the tree key" do
          tree = Tree(Symbol).new("/", :root)
          result = Result(Symbol).new
          result.use tree

          result.key.should eq("/")
        end
      end

      context "using multiple trees" do
        it "combines the tree keys" do
          tree1 = Tree(Symbol).new("/", :root)
          tree2 = Tree(Symbol).new("about", :about)
          result = Result(Symbol).new
          result.use tree1
          result.use tree2

          result.key.should eq("/about")
        end
      end
    end

    describe "#use" do
      it "uses the tree payload" do
        tree = Tree(Symbol).new("/", :root)
        result = Result(Symbol).new
        result.found?.should be_falsey

        result.use tree
        result.found?.should be_truthy
        result.leaves.should eq(tree.leaves)
      end

      it "allow not to assign payload" do
        tree = Tree(Symbol).new("/", :root)
        result = Result(Symbol).new
        result.found?.should be_falsey

        result.track tree
        result.found?.should be_falsey
      end
    end
  end
end

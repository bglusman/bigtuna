require 'test_helper'

module BigTuna
  class Hooks::RaisingHook
    NAME = "raising_hook"

    def build_failed(build, config); raise "build_failed"; end
    def build_finished(build, config); raise "build_finished"; end
  end
end

class HooksUnitTest < ActiveSupport::TestCase
  def setup
    super
    `cd test/files; mkdir koss; cd koss; git init; echo "my file" > file; git add file; git commit -m "my file added"`
  end

  def teardown
    FileUtils.rm_rf("test/files/koss")
    super
  end

  test "if hook produces error it is handled and marks build as hook failed" do
    with_hook_enabled(BigTuna::Hooks::RaisingHook) do
      project = project_with_steps({
        :name => "Koss",
        :vcs_source => "test/files/koss",
        :max_builds => 2,
        :hooks => {"raising_hook" => "raising_hook"},
      }, "true")

      project.build!
      run_delayed_jobs()
      build = project.recent_build
      assert_equal Build::STATUS_HOOK_ERROR, build.status
    end
  end

  test "if hook is not enabled it won't get executed" do
    with_hook_enabled(BigTuna::Hooks::RaisingHook) do
      project = project_with_steps({
        :name => "Koss",
        :vcs_source => "test/files/koss",
        :max_builds => 2,
        :hooks => {"raising_hook" => "raising_hook"},
      }, "true")
      hook = project.hooks.first
      hook.hooks_enabled.delete("build_finished")
      hook.save!
      assert ! hook.hook_enabled?("build_finished")
      assert hook.hook_implemented?("build_finished")

      project.build!
      run_delayed_jobs()
      build = project.recent_build
      assert_equal Build::STATUS_OK, build.status
    end
  end
end

# Changelog

## v1.1.6 (2022-02-20)
    * Improve Waffle.Storage.S3 moduledoc (#90)
    * Fix links to other storage providers (#92)
    * Allow setting a custom bucket from scope (#31)
    * Update dependencies

## v1.1.5 (2021-08-12)
    * Update dependencies
    * Add support for custom validation error message (#84)

## v1.1.4 (2021-02-25)
    * Upgrade deps for fixing compile warning in Elixir 1.11 (#74)
    * Use elixir v1.11 as base image
    * Make readme contain less marketing links
    * Migrate to GitHub Actions from CodeShip CI


## v1.1.3 (2020-09-14)
  * fix missing comma in configuration (#65)
  * request headers for remote file (#61)

      By default, when downloading files from remote path request headers are empty,
      but if you wish to provide your own, you can override the `remote_file_headers/1`
      function in your definition module.

## v1.1.2 (2020-09-03)
  * Improve docs of getting started and multiple minor changes (#55)
  * refactor Waffle.File.do_generate_temporary_path/1 (#56)

## v1.1.1 (2020-08-02)
  * update dependencies
  * add correct S3 setup to documentation
  * Use correct extension for temp files (#53)
  * Fix typo in comment (#52)
  * Update path in getting started guide to the correct generated path (#48)
  * add Aliyun OSS storage provider link (#45)

## v1.1.0 (2020-05-12)
  * update dependencies
  * respect `content-disposition` header (#41)
  * `ex_aws` needs to be at least 2.1.2 (#43)
  * add attribution to the original work (#39)

### Notes
Now, the Waffle respects `content-disposition` header. It means that
for remote uploads by url, we'll check for this header and will
respect the filename from it. In other words, we'll save a file with a
name from `content-disposition` header.

## v1.0.1 (2020-03-23)
  * Handle special S3 escaping (#32)
  * add branding for project (#34)

## v1.0.0 (2020-02-04)
  * remove poison and update dependencies (#30)
  * define remote url as an attribute #29
  * respect spaces in remote filenames (#28)

### Upgrade instructions
`ExAws` dependency was upgraded to the current version. Since most of
community packages are migrating to `Jason` as a default library to
work with JSON, we've decided to migrate `Waffle` as well. You can
still use `Poison` as your JSON adapter, in such case just add it as a
dependency.

#### Before
```
config :ex_aws,
  ...
```
#### After
```
config :ex_aws,
  json_codec: Jason
```

## v0.0.4 (2019-12-16)
  * Fixes link to waffle_ecto (#16)
  * add credo to project (#17)
  * correct misspellings in documentation (#19)
  * Change reference to arc_gcs to refer to waffle_gcs instead (#22)
  * add documentation for modules (#25)
  * upgrade hackney to fix remote file downloading (#26)

## v0.0.3 (2019-09-09)
  * add new file from remote path with new filename (#13)
  * support specifying asset host for local storage (#12)
  * allow storage path to be different from url (#11)

## v0.0.2 (2019-09-02)
  * Clean up all temp files created during processing and storage (#9)
  * Bypass delete on skipped versions (#8)
  * add documentation for phoenix integration (#7)
  * add documentation for local development setup (#5)
  * update dependencies (#4)
  * add codeship integration (#2)

## v0.0.1 (2019-08-25)
  * Move project to a new repository and change name to `Waffle`

## v0.11.0 (2018-10-04)
  * (Dependency) `:httpoison` removed in favor of `:hackney`
  * (Enhancement) Proper generator file location for Phoenix 1.3+
  * (Enhancement) Support setting asset_host to `false` in the app config to revert to the default
  * (Enhancement) Allow overriding asset_host in an individual definition module
  * (Enhancement) Definitions can conditionally skip a version or transformation

## v0.10.0 (2018-06-19)
  * (Dependency) `:ex_aws` increased to `~> 2.0`
  * (Dependency) `:ex_aws_s3` added at `~> 2.0`

## v0.9.0 (2018-06-19)
  * (Enhancement) Allow overriding the destination bucket in an upload definition. See (https://github.com/stavro/arc/pull/206)
  * (Enhancement) Allow overriding the `storage_dir` via configuration
  * (Enhancement) Skip uploading all files if any of the versions fail (PR: https://github.com/stavro/arc/pull/218)

## v0.8.0 (2017-04-20)
  * (Enhancement) Fix elixir warnings.
  * (Enhancement) Allow delete/1 to be overridden.
  * (Enhancement) Deletions follow same async behavior as uploads.
  * (Minor Breaking Change) URL encode returned urls.  If you were explicitly encoding them yourself, you don't need to do this anymore.

## v0.7.0 (2017-02-07)
  * Require Elixir v1.4
  * Relax package dependencies
  * Fix Elixir v1.4 warnings
  * (Enhancement) Disable asynchronous processing via module attribute `@async false`.
  * (Enhancement) Add retry functionality to remote path uploader

> v0.7.0 Requires Elixir 1.4 or above, due to enhancements made with ExAws and Task Streaming

## v0.6.0 (2016-12-19)
  * (Enhancement) Allow asset host to be set via an environment variable
  * (Enhancement) Allow downloading and saving remote files
  * (Enhancement) Move Arc storage module to config
  * (Bugfix) Split conversion arguments correctly when a file name has a space in it
  * (Bugfix) S3 object headers must be transferred to ExAws as a keyword list, not a map
  * (Bugfix) Don't prepend a forward-slash to local storage urls if the url already starts with a forward-slash.

## v0.6.0-rc3 (2016-10-20)
  * (Dependencies) - Upgrade `ex_aws` to rc3

## v0.6.0-rc2 (2016-10-20)
  * (Dependencies) - Upgrade `ex_aws` to rc2

## v0.6.0-rc1 (2016-10-04)
  * (Dependencies) - Removed `httpoison` as an optional dependency, added `sweet_xml` and `hackney` as optional dependencies (required if using S3).
  * (Enhancement) File streaming to S3 - Allows the uploading of large files to S3 without reading to memory first.
  * (Enhancement) Allow Arc to transform and store directly on binary input.
  * (Bugfix - backwards incompatible) Return error tuple rather than raising `Arc.ConvertError` if the transformation fails.
  * (Bugfix) Update `:crypto` usage to `:crypto.strong_rand_bytes`
  * (Enhancement) Optionally set S3 bucket from runtime env var  (`config :arc, bucket: {:system, "S3_BUCKET"}`)
  * (Enhancement) Temporary files created during transformations now include the file extension.
  * (Bugfix) Add a leading slash to **urls** generated from the Local storage adapter.

## v0.5.3 (2016-06-21)
  * (Enhancement) Relax ex_aws dependency to allow `~> 0.5.0`

## v0.5.2 (2016-04-27)
  * (Enhancement) Allow returning a list of arguments for transformations to preserve desired groupings.

## v0.5.1 (2016-03-02)
  * (Enhancement) Raise a more helpful error message when attempting a transformation with an executable which cannot be found.

## v0.5.0 (2016-03-02)
  * (Enhancement) Allow transforms via arbitrary system executables.
  * (Enhancement) Allow transforms to supply a function to define the transformation args.
  * (Deprecation) Deprecate usage of {:noaction} in favor of :noaction for transformation responses.

Upgrade instructions from 0.4.x to 0.5.x:

Arc now favors explicitness in file extension changes rather than scanning with a Regex.  If you have a `convert` transformation which changes the file extension (through the parameter `-format png` argument), you must explicitly add a third tuple argument in the conversion noting the final extension.

Example:

```elixir
# Change this:
  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png"}
  end

# To this:
  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png} #<--- Note the third tuple argument with the output file extension
  end
```


## v0.4.1 (2016-02-28)
  * (Bugfix) Fix regression using the local filesystem introduced via v0.4.0.

## v0.4.0 (2016-02-25)
  * (Bugfix) Surface errors from ExAws put operations.  Parse ExAws errors and return tuple of form `{:error, List.t}` when an error is encountered.

To upgrade and properly support parsing aws errors, add `:poison` to your list of dependencies.

> Optional dependency added, prompting a minor version bump.  While not a strict backwards incompatibility, Arc users should take note of the change as more than an internal change.

## v0.3.0 (2016-01-22)
  * (Enhancement) Introduce `Definition.delete/2`

> While there is no strict backwards incompatibility with the public API, a number of users have been using `Arc.Storage.S3.delete/3` as a public API due to a lack of a fully supported delete method.  This internal method has now changed slightly, thus prompting more than a patch release.

## v0.2.3 (2016-01-22)
  * (Enhancement) Allow specifying custom s3 object headers through the definition module via `s3_object_headers/2`.

## v0.2.2 (12-14-2015)
  * (Enhancement) Allow the version transformation and storage timeout to be specified in configuration `config :arc, version_timeout: 15_000`.

## v0.2.1 (12-11-2015)
  * (Bugfix) Raise `Arc.ConvertError` if ImageMagick's `convert` tool exits unsuccessfully.

## v0.2.0 (12-11-2015)
  * (Breaking Change) Erlcloud has been removed in favor of ExAws.
  * (Enhancement) Added a configuration parameter to generate urls in the `virtual_host` style.

### Upgrade Instructions
Since `erlcloud` has been removed from `arc`, you must also remove it from your dependency graph as well as your application list. In its place, add `ex_aws` and `httpoison` to your dependencies as well as application list. Next, remove the aws credential configuration from arc:

```elixir
# BEFORE
config :arc,
  access_key_id: "###",
  secret_access_key: "###",
  bucket: "uploads"

#AFTER
config :arc,
  bucket: "uploads"

# (this is the default ex_aws config... if your keys are not in environment variables you can override it here)
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
```

Read more about how ExAws manages configuration [here](https://github.com/CargoSense/ex_aws).

## v0.1.4 (11-10-2015)
  * (Enhancement: Local Storage) Filenames which contain path separators will flatten out as expected prior to moving copying the file to its destination.

## v0.1.3 (09-15-2015)

  * (Enhancement: Url Generation) `default_url/2` introduced to definition module which passes the given scope as the second parameter.  Backwards compatibility is maintained for `default_url/1`.

## v0.1.2 (09-08-2015)

  * (Bugfix: Storage) Bugfix for referencing atoms in the file name.

## v0.1.1

  * (Enhancement: Storage) Add the local filesystem as a storage option.

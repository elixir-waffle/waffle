[hex-img]: http://img.shields.io/hexpm/v/waffle.svg
[hex-url]: https://hex.pm/packages/waffle

[hexdocs-img]: http://img.shields.io/badge/hexdocs-documentation-brightgreen.svg
[hexdocs-url]: https://hexdocs.pm/waffle

[evrone-img]: https://img.shields.io/badge/Sponsored_by-Evrone-brightgreen.svg
[evrome-url]: https://evrone.com?utm_source=waffle

# Waffle [![Sponsored by Evrone][evrone-img]][evrome-url]

[![Hex.pm Version][hex-img]][hex-url]
[![waffle documentation][hexdocs-img]][hexdocs-url]

<img align="right" width="176" height="120"
     alt="Waffle is a flexible file upload library for Elixir"
     src="https://elixir-waffle.github.io/waffle/assets/logo.svg">

Waffle is a flexible file upload library for Elixir with straightforward integrations for ImageMagick.

[Documentation](https://hexdocs.pm/waffle)

## AWS S3 Integration

Integration with AWS S3 has been split into a separate project. See the [waffle_s3](https://github.com/waffle-elixir/waffle_s3) repo for more details. For a "quick upgrade", simply:

- Add `{:waffle_s3, "~> 1.1"}` to your `mix.exs` deps.
- Remove any previous references to AWS-specific modules that are not needed outside your application code (e.g. `:ex_aws_s3`).
- Run `mix deps.get` and `mix deps.update`. This should (a) get the Waffle S3 module and (b) remove any previous application dependencies for AWS S3 that aren't required outside of Waffle.

## Attribution

Great thanks to Sean Stavropoulos (@stavro) for the original awesome work on the library.

This project is forked from [Arc](https://github.com/stavro/arc) from the version `v0.11.0`.

## License

Copyright 2019 Boris Kuznetsov <me@achempion.com>

Copyright 2015 Sean Stavropoulos

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

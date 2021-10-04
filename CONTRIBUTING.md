# Contributing Guidelines

This document contains information and guidelines about contributing to this project.
Please read it before you start participating.

**Topics**

* [Asking Questions](#asking-questions)
* [Reporting Security Issues](#reporting-security-issues)
* [Reporting Issues](#reporting-other-issues)
* [Triage Issues](#triage-issues)
* [Submitting Pull Requests](#submitting-pull-requests)
* [Developers Certificate of Origin](#developers-certificate-of-origin)
* [Code of Conduct](#code-of-conduct)

## Asking Questions

**We don't use GitHub as a support forum.**
For any usage questions that are not specific to the project itself, please ask on [Stack Overflow](https://stackoverflow.com) instead. By doing so, you'll be more likely to quickly solve your problem, and you'll allow anyone else with the same question to find the answer. This also allows maintainers to focus on improving the project for others.

If you'd like to discuss Alamofire best practices, common usage patterns, ideas for new features, or ongoing development, please use our [Swift Forums](https://forums.swift.org/c/related-projects/alamofire/).

## Reporting Security Issues

The Alamofire Software Foundation takes security seriously.
If you discover a security issue, please bring it to our attention right away!

Please **DO NOT** file a public issue, instead send your report privately to <security@alamofire.org>. This will help ensure that any vulnerabilities that _are_ found can be [disclosed responsibly](https://en.wikipedia.org/wiki/Responsible_disclosure) to any affected parties.

## Reporting Other Issues

A great way to contribute to the project is to send a detailed issue when you encounter a problem. We always appreciate a well-written, thorough bug report.

Check that the project issues database doesn't already include that problem or suggestion before submitting an issue. If you find a match, feel free to vote for the issue by adding a reaction. Doing this helps prioritize the most common problems and requests.

When reporting issues, please fill out our issue template. The information the template asks for will help us review and fix your issue faster.

## Triage Issues [![Open Source Helpers](https://www.codetriage.com/alamofire/alamofire/badges/users.svg)](https://www.codetriage.com/alamofire/alamofire)

You can triage issues which may include reproducing bug reports or asking for vital information, such as version numbers or reproduction instructions. If you would like to start triaging issues, one easy way to get started is to [subscribe to alamofire on CodeTriage](https://www.codetriage.com/alamofire/alamofire).

## Submitting Pull Requests

You can contribute by fixing bugs or adding new features. For larger code changes, we first recommend discussing them in our [Github issues](https://github.com/Alamofire/Alamofire/issues) or on our [Swift Forums](https://forums.swift.org/c/related-projects/alamofire/). When submitting a pull request, please add relevant tests and ensure your changes don't break any existing tests (see [Automated Tests](#automated-tests) below).

### Automated Tests

Alamofire's tests depend on our [Firewalk](https://github.com/Alamofire/Firewalk) test server. To run the automated tests, you first need to have the server running locally. 

In your terminal, run the following commands:
- To install Firewalk: `brew install alamofire/alamofire/firewalk`
- To run and detach the server: `firewalk &`
- To stop the server, run `kill` and provide the pid output after launch.

## Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

- (a) The contribution was created in whole or in part by me and I
      have the right to submit it under the open source license
      indicated in the file; or

- (b) The contribution is based upon previous work that, to the best
      of my knowledge, is covered under an appropriate open source
      license and I have the right under that license to submit that
      work with modifications, whether created in whole or in part
      by me, under the same open source license (unless I am
      permitted to submit under a different license), as indicated
      in the file; or

- (c) The contribution was provided directly to me by some other
      person who certified (a), (b) or (c) and I have not modified
      it.

- (d) I understand and agree that this project and the contribution
      are public and that a record of the contribution (including all
      personal information I submit with it, including my sign-off) is
      maintained indefinitely and may be redistributed consistent with
      this project or the open source license(s) involved.

## Code of Conduct

The Code of Conduct governs how we behave in public or in private
whenever the project will be judged by our actions.
We expect it to be honored by everyone who contributes to this project.

See [CONDUCT.md](https://github.com/Alamofire/Foundation/blob/master/CONDUCT.md) for details.

---

*Some of the ideas and wording for the statements above were based on work by the [Docker](https://github.com/docker/docker/blob/master/CONTRIBUTING.md) and [Linux](https://elinux.org/Developer_Certificate_Of_Origin) communities. We commend them for their efforts to facilitate collaboration in their projects.*

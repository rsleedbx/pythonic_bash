# Contributing to Pythonic Bash

Thank you for your interest in contributing to pythonic_bash!

## Development Setup

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/pythonic_bash.git
cd pythonic_bash

# Install dependencies
brew install yq  # macOS
# or
sudo snap install yq  # Linux

# Ensure bash 4.0+
bash --version
```

## Running Tests

```bash
# Run all tests
bash tests/test_pythonic_bash.sh

# Run specific example
bash examples/example_usage.sh
```

## Code Style

- Use 4 spaces for indentation
- Add comments for complex logic
- Follow existing patterns for consistency
- Include error handling
- Preserve caller's shell options (e.g., set -u state)

## Testing Requirements

All PRs must:
- Pass all 12 existing tests
- Add tests for new functionality
- Not break backward compatibility
- Include documentation updates

## Areas for Contribution

- [ ] Array support (currently only objects)
- [ ] Custom separator (not just `__`)
- [ ] Type preservation (numbers vs strings)
- [ ] Schema validation
- [ ] Performance optimizations
- [ ] Additional helper functions
- [ ] More examples

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`bash tests/test_pythonic_bash.sh`)
5. Commit (`git commit -m 'Add amazing feature'`)
6. Push (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
